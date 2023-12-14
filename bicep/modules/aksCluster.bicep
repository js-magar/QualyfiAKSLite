param aksClusterName string
param entraGroupID string
param logAnalyticsWorkspaceID string
param appGatewayID string
param vnetName string
param systemSubnetName string
param appSubnetName string
param podSubnetName string
param adminUsername string
param adminPasOrKey string
param costSaving bool
param prefix string = 'aks-jm'
param acrPullRDName string 
param netContributorRoleDefName string 

param location string
//condition ? valueIfTrue : valueIfFalse
var maxPods = costSaving ? 150 : 250
var maxCount=costSaving ? 1 : 20
var minCount=costSaving ? 1 : 1
var startingCount=costSaving ? 1 : 2

var aksClusterUserDefinedManagedIdentityName = '${prefix}-mi-cluster-${location}'
var aksClusterDNSPrefix ='akscluster-jash'
var rgName = resourceGroup().name
var acrPullRoleAssignmentName = guid('${resourceGroup().id}acrPullRoleAssignment')
var appGwNetContributorRoleAssignmentName = guid(appGatewayID, netContributorRoleId, resourceGroup().id)
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRDName)
var netContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', netContributorRoleDefName)

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {name: vnetName}
resource AppPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: appSubnetName,parent: virtualNetwork}
resource SystemPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: systemSubnetName,parent: virtualNetwork}
resource PodSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: podSubnetName,parent: virtualNetwork}

resource aksClusterUserDefinedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: aksClusterUserDefinedManagedIdentityName
  location: location
}
resource aksClusterResource 'Microsoft.ContainerService/managedClusters@2023-08-01' = {
  name: aksClusterName
  location: location
  sku: {
      name: 'Base'
      tier: 'Free'
  }
  identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${aksClusterUserDefinedManagedIdentity.id}': {
        }
      }
  }
  properties: {
    kubernetesVersion: '1.27.7' 
    enableRBAC: true
    dnsPrefix: aksClusterDNSPrefix
    disableLocalAccounts:true
    aadProfile:{
        managed:true
        adminGroupObjectIDs:[
          '${entraGroupID}'
        ]
        tenantID:subscription().tenantId
    }
    agentPoolProfiles: [
        {name: 'systempool'
          count: startingCount
          vmSize: 'Standard_DS2_v2' 
          vnetSubnetID:SystemPoolSubnet.id
          podSubnetID:PodSubnet.id
          maxPods:maxPods
          maxCount:maxCount
          minCount:minCount
          enableAutoScaling:true
          osType: 'Linux'
          osSKU: 'CBLMariner'
          mode: 'System'

        }
        {name: 'apppool'
          count: startingCount
          vmSize: 'Standard_DS2_v2' 
          vnetSubnetID:AppPoolSubnet.id
          podSubnetID:PodSubnet.id
          maxPods:maxPods
          maxCount:maxCount
          minCount:minCount
          enableAutoScaling:true
          osType: 'Linux'
          osSKU: 'CBLMariner'
          mode: 'System'
        }
    ]
    linuxProfile: {
        adminUsername: adminUsername
        ssh:{
          publicKeys: [
            {
              keyData: 'ssh-rsa ${adminPasOrKey}\n'
            }
          ]
        }
    }
    networkProfile: {
      networkPlugin:'azure'
      networkPolicy: 'azure'
      networkDataplane:'azure'
    }
    nodeResourceGroup:'MC-${rgName}'
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceID
        }
      }
      ingressApplicationGateway: {
        config: {
          applicationGatewayId: appGatewayID
        }
        enabled: true
      }
      azureKeyvaultSecretsProvider: {
        config: {
          enableSecretRotation: 'false'
        }
        enabled: true
      }
    }
    azureMonitorProfile: {
      metrics: {
        enabled: true
      }
    }
  }
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: acrPullRoleAssignmentName
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: aksClusterResource.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}
resource appGwNetContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: appGwNetContributorRoleAssignmentName
  properties: {
    roleDefinitionId: netContributorRoleId
    principalId: aksClusterResource.properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

output aksClusterId string = aksClusterResource.id
output aksClusterName string = aksClusterResource.name
output aksClusterUserDefinedManagedIdentityName string = aksClusterUserDefinedManagedIdentity.name
