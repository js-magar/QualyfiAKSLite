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

param location string
var maxPods = 250
var maxCount=20
var minCount=1
var startingCount=1

var aksClusterUserDefinedManagedIdentityName = 'mi-${aksClusterName}-${location}'
var aksClusterDNSPrefix ='akscluster-jash'
var rgName = resourceGroup().name

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
    /*
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${aksClusterUserDefinedManagedIdentity.id}': {
        }
      }*/
      type:'SystemAssigned'
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
          count: 2
          vmSize: 'Standard_DS2_v2' 
          vnetSubnetID:SystemPoolSubnet.id
          podSubnetID:PodSubnet.id
          maxPods:250
          maxCount:20
          minCount:1
          enableAutoScaling:true
          osType: 'Linux'
          osSKU: 'CBLMariner'
          mode: 'System'

        }
        {name: 'apppool'
          count: 2
          vmSize: 'Standard_DS2_v2' 
          vnetSubnetID:AppPoolSubnet.id
          podSubnetID:PodSubnet.id
          maxPods:250
          maxCount:20
          minCount:1
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
      //outboundType: 'userAssignedNATGateway'
      networkPlugin:'azure'
      networkPolicy: 'azure'
      networkDataplane:'azure'
      //serviceCidr: aksClusterServiceCidr
      //dnsServiceIP: aksClusterDnsServiceIP
    }
    nodeResourceGroup:'MC-${rgName}'
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceID
        }
      }/*
      aciConnectorLinux: {
        enabled: false
      }
      azurepolicy: {
        enabled: true
        config: {
          version: 'v2'
        }
      }
      kubeDashboard: {
        enabled: false
      }*/
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
output aksClusterId string = aksClusterResource.id
output aksClusterUserDefinedManagedIdentityName string = aksClusterUserDefinedManagedIdentity.name
