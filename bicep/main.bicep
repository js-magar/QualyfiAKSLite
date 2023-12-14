param entraGroupID string
param acrRoleDefName string 
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
param prefix string = 'aks-jm'

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


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name:logAnalyticsWorkspaceName
  location:location
  properties:{
    features:{
      enableLogAccessUsingOnlyResourcePermissions:true
    }
  }
}
module virtualNetwork 'modules/networking.bicep' = {
  name: 'virtualNetworkDeployment'
  params:{
    location :location
    natGatewayPIPName :natGatewayPIPName
    natGatewayName :natGatewayName
    virtualNetworkName :virtualNetworkName
    vnetAddressPrefix :vnetAddressPrefix
    systemPoolSubnetName :systemPoolSubnetName
    systemPoolSubnetAddressPrefix :systemPoolSubnetAddressPrefix
    appPoolSubnetName :appPoolSubnetName
    appPoolSubnetAddressPrefix :appPoolSubnetAddressPrefix
    podSubnetName :podSubnetName
    podSubnetAddressPrefix :podSubnetAddressPrefix
    appGatewaySubnetName :appGatewaySubnetName
    appGatewaySubnetAddressPrefix :appGatewaySubnetAddressPrefix
    bastionSubnetName :bastionSubnetName
    bastionSubnetAddressPrefix  :bastionSubnetAddressPrefix
    appgwbastionPrefix :appgwbastionPrefix
  }
}
module appGateway 'modules/appGateway.bicep'={
  name:'appGatewayDeployment'
  params:{
    appGatewaySubnetID : virtualNetwork.outputs.appGatewaySubnetID
    appGatewayPIPName:appGatewayPIPName
    appGatewayName:appGatewayName
    location:location
  }
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
    appPoolSubnetID: virtualNetwork.outputs.appPoolSubnetID
    systemPoolSubnetID: virtualNetwork.outputs.systemPoolSubnetID
    podPoolSubnetID: virtualNetwork.outputs.podPoolSubnetID
    location:location
    adminUsername:adminUsername
    adminPasOrKey:adminPasOrKey
    acrPullRDName:acrRoleDefName
    netContributorRoleDefName:netContributorRoleDefName
  }
}

module bastion 'modules/bastion.bicep' = {
  name: 'bastionDeployment'
  params:{
    location:location
    bastionSubnetID:virtualNetwork.outputs.bastionSubnetID
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
    aksClusterName:aksCluster.outputs.aksClusterName
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
