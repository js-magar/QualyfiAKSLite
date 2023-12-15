param aksClusterName string
param entraGroupID string
param logAnalyticsWorkspaceID string
param appGatewayID string
param adminUsername string
param adminPasOrKey string
param acrPullRDName string 
param netContributorRoleDefName string 
param appPoolSubnetID string
param systemPoolSubnetID string
param podPoolSubnetID string

param location string
var maxPods = 250
var maxCount= 20
var minCount= 1
var startingCount= 2

var aksClusterDNSPrefix ='akscluster-jash'
var rgName = resourceGroup().name
var acrPullRoleAssignmentName = guid('${resourceGroup().id}acrPullRoleAssignment')
var appGwNetContributorRoleAssignmentName = guid(appGatewayID, netContributorRoleId, resourceGroup().id)
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRDName)
var netContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', netContributorRoleDefName)

resource aksClusterResource 'Microsoft.ContainerService/managedClusters@2023-08-01' = {
  name: aksClusterName
  location: location
  sku: {
      name: 'Base'
      tier: 'Free'
  }
  identity: {
      type: 'SystemAssigned'
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
          vnetSubnetID:systemPoolSubnetID
          podSubnetID:podPoolSubnetID
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
          vnetSubnetID:appPoolSubnetID
          podSubnetID:podPoolSubnetID
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
