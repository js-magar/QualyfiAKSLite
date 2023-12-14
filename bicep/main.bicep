param entraGroupID string
param acrRoleDefName string 
param contributorRoleDefName string
param readerRoleDefName string
param netContributorRoleDefName string
param keyVaultAdminRoleDefName string
param keyVaultUserRoleDefName string
param monitoringReaderRoleDefName string
param monitoringDataReaderRoleDefName string
param grafanaAdminRoleDefName string
param adminUsername string
param adminPasOrKey string
param aksClusterName string
param acrName string
param location string
param keyVaultName string
param name string
param prefix string = 'aks-jm'
param prefixWO string = 'aksjm'

var vnetAddressPrefix = '10'
var virtualNetworkName = '${prefix}-vnet'

var systemPoolSubnetName = 'SystemPoolSubnet'
var systemPoolSubnetAddressPrefix = '1'
var appPoolSubnetName = 'AppPoolSubnet'
var appPoolSubnetAddressPrefix = '2'


var podSubnetAddressPrefix = '3'
var podSubnetName = 'PodSubnet'

var appgwbastionPrefix ='4'
var appGatewaySubnetAddressPrefix = '1'
var appGatewaySubnetName = 'AppgwSubnet'
param appGatewayName string
var appGatewayPIPName = '${prefix}-pip-agw-${location}-001'

var bastionSubnetAddressPrefix = '2'
param bastionName string
var bastionSubnetName = 'AzureBastionSubnet'
var bastionPIPName = '${prefix}-pip-bas-${location}-001'

var natGatewayName = '${prefix}-ng-${location}-001'
var natGatewayPIPName = '${prefix}-pip-ng-${location}-001'

var logAnalyticsWorkspaceName = '${prefix}-log-acr-${location}-1'

var natGatewayID = natGateway.id 

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name:logAnalyticsWorkspaceName
  location:location
  properties:{
    features:{
      enableLogAccessUsingOnlyResourcePermissions:true
    }
  }
}
resource natGatewayPIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: natGatewayPIPName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}
resource natGateway 'Microsoft.Network/natGateways@2022-05-01' = {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [{id: natGatewayPIP.id}]
  }
}
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '${vnetAddressPrefix}.0.0.0/8'
      ]
    }
    subnets: [
      {
        name: systemPoolSubnetName
        properties: {
          addressPrefix: '${vnetAddressPrefix}.${systemPoolSubnetAddressPrefix}.0.0/16'
          natGateway:{
            id:natGatewayID
          }
        }
      }
      {
        name: appPoolSubnetName
        properties: {
          addressPrefix: '${vnetAddressPrefix}.${appPoolSubnetAddressPrefix}.0.0/16'
          natGateway:{
            id:natGatewayID
          }
        }
      }
      {
        name: podSubnetName
        properties: {
          addressPrefix: '${vnetAddressPrefix}.${podSubnetAddressPrefix}.0.0/16'
          natGateway:{
            id:natGatewayID
          }
          delegations: [
            {
              name: 'Delegation'
              properties: {
                serviceName: 'Microsoft.ContainerService/managedClusters'
              }
            }
          ]
        }
      }
      {
        name: appGatewaySubnetName
        properties: {
          addressPrefix: '${vnetAddressPrefix}.${appgwbastionPrefix}.${appGatewaySubnetAddressPrefix}.0/24'
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: '${vnetAddressPrefix}.${appgwbastionPrefix}.${bastionSubnetAddressPrefix}.0/24'
        }
      }
    ]
  }
}
module appGateway 'modules/appGateway.bicep'={
  name:'appGatewayDeployment'
  params:{
    appGatewaySubnetName : appGatewaySubnetName
    appGatewayPIPName:appGatewayPIPName
    appGatewayName:appGatewayName
    virtualNetworkName:virtualNetworkName
    location:location
  }
  dependsOn:[
    virtualNetwork
  ]
}
module acr 'modules/acr.bicep' = {
  name:'appContainerRegistryDeployment'
  params:{
    acrName:acrName
    logAnalyticsName:logAnalyticsWorkspace.name
    location:location
  }
}
module aksCluster 'modules/aksCluster.bicep' = {
  name: 'aksClusterDeployment'
  params:{
    aksClusterName:aksClusterName
    entraGroupID:entraGroupID
    logAnalyticsWorkspaceID :logAnalyticsWorkspace.id
    appGatewayID:appGateway.outputs.appGatwayId
    vnetName:virtualNetworkName
    appSubnetName:appPoolSubnetName
    systemSubnetName:systemPoolSubnetName
    podSubnetName:podSubnetName
    location:location
    adminUsername:adminUsername
    adminPasOrKey:adminPasOrKey
    acrPullRDName:acrRoleDefName
    netContributorRoleDefName:netContributorRoleDefName
  }
}
module metrics 'modules/monitor_metrics.bicep' = {
  name: 'metricsDeployment'
  params:{
    location:location
    clusterName:aksClusterName  
    entraGroupID:entraGroupID
    monitoringReaderRoleDefName:monitoringReaderRoleDefName
    monitoringDataReaderRoleDefName:monitoringDataReaderRoleDefName
    grafanaAdminRoleDefName:grafanaAdminRoleDefName
  }
  dependsOn:[
    acr
    aksCluster
    appGateway
  ]
}
module bastion 'modules/bastion.bicep' = {
  name: 'bastionDeployment'
  params:{
    location:location
    vnetName:virtualNetwork.name
    bastionSubnetName:bastionSubnetName
    bastionName:bastionName
    bastionPIPName:bastionPIPName
  }
}
module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVaultDeployment'
  params:{
    location:location
    keyVaultName:keyVaultName
  }
}
module keyVaultMI 'modules/keyVaultMI.bicep' = {
  name:'keyVaultMIDeployment'
  params:{
    keyVaultName:keyVault.outputs.keyVaultName
    kvManagedIdentityName:keyVault.outputs.kvIdentityUserDefinedManagedIdentityName
    keyVaultUserRoleDefName:keyVaultUserRoleDefName
    keyVaultAdminRoleDefName:keyVaultAdminRoleDefName
    appGWName:appGateway.outputs.appGatwayName
    aksClusterName:aksCluster.outputs.aksClusterName
  }
}
