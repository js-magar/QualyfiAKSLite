param keyVaultName string
param aksResourceID string
param acrPullRDName string 
param contributorRoleDefName string
param readerRoleDefName string
param keyVaultUserRoleDefName string
param keyVaultAdminRoleDefName string
param netContributorRoleDefName string
param monitoringReaderRoleDefName string
param monitoringDataReaderRoleDefName string
param grafanaAdminRoleDefName string
param aksClusterUserDefinedManagedIdentityName string
param applicationGatewayUserDefinedManagedIdentityName string
param kvManagedIdentityName string
param aksClusterName string
param grafanaName string
param groupId string
param prometheusName string

var aksContributorRoleAssignmentName = guid(aksClusterUserDefinedManagedIdentity.id, contributorRoleId, resourceGroup().id)
var appGwContributorRoleAssignmentName = guid(applicationGatewayUserDefinedManagedIdentity.id, contributorRoleId, resourceGroup().id)
var appGwNetContributorRoleAssignmentName = guid(applicationGatewayUserDefinedManagedIdentity.id, netContributorRoleId, resourceGroup().id)
var keyVaultReaderRoleAssignmentName = guid(kvUserDefinedManagedIdentity.id, readerRoleId, resourceGroup().id)
var acrPullRoleAssignmentName = guid('${resourceGroup().id}acrPullRoleAssignment')

var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRDName)
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleDefName)
var readerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleDefName)
var netContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', netContributorRoleDefName)
var kvUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultUserRoleDefName)
var kvAdminRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdminRoleDefName)
var monitoringReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringReaderRoleDefName)
var monitoringDataReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringDataReaderRoleDefName)
var grafanaAdminRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', grafanaAdminRoleDefName)

resource applicationGatewayUserDefinedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing  = {name: applicationGatewayUserDefinedManagedIdentityName}
resource aksClusterUserDefinedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {name: aksClusterUserDefinedManagedIdentityName}
resource kvUserDefinedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing  = {name: kvManagedIdentityName}
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {name: keyVaultName}
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-08-01' existing = {name:aksClusterName}
resource azureMonitorWorkspace 'Microsoft.Monitor/accounts@2023-04-03' existing = {name:prometheusName}
resource managedGrafana 'Microsoft.Dashboard/grafana@2022-08-01' existing =  {name: grafanaName}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: acrPullRoleAssignmentName
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: reference(aksResourceID, '2023-08-01', 'Full').properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}
resource aksContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: aksContributorRoleAssignmentName
  properties: {
    roleDefinitionId: contributorRoleId
    description: 'Assign the cluster user-defined managed identity contributor role on the resource group.'
    principalId: aksClusterUserDefinedManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
resource appGwContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: appGwContributorRoleAssignmentName
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: reference(aksResourceID, '2023-08-01', 'Full').properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}
resource appGwNetContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: appGwNetContributorRoleAssignmentName
  properties: {
    roleDefinitionId: netContributorRoleId
    principalId: reference(aksResourceID, '2023-08-01', 'Full').properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}
resource keyVaultReaderRoleAssignment  'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: keyVaultReaderRoleAssignmentName
  properties: {
    roleDefinitionId: readerRoleId
    principalId: kvUserDefinedManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
resource keyVaultAdminRoleAssignment  'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kvUserDefinedManagedIdentity.id, kvAdminRoleId, resourceGroup().id)
  properties: {
    roleDefinitionId: kvAdminRoleId
    principalId: kvUserDefinedManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
resource keyVaultSecretsUserApplicationGatewayIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  {
  name: guid(keyVault.id, 'ApplicationGateway', 'keyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: kvUserRoleId
    principalType: 'ServicePrincipal'
    principalId: applicationGatewayUserDefinedManagedIdentity.properties.principalId
  }
}
resource keyVaultCSIdriverSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, 'CSIDriver', kvUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: kvUserRoleId
    principalType: 'ServicePrincipal'
    principalId: aksCluster.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId
  }
}
resource monitoringReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name:  guid(managedGrafana.name, azureMonitorWorkspace.name, monitoringReaderRoleId)
  scope: azureMonitorWorkspace
  properties: {
    roleDefinitionId: monitoringReaderRoleId
    principalId: managedGrafana.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
resource monitoringDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name:  guid(managedGrafana.name, azureMonitorWorkspace.name, monitoringDataReaderRoleId)
  scope: azureMonitorWorkspace
  properties: {
    roleDefinitionId: monitoringDataReaderRoleId
    principalId: managedGrafana.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
resource grafanaAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name:  guid(managedGrafana.name, groupId, grafanaAdminRoleId)
  scope: managedGrafana
  properties: {
    roleDefinitionId: grafanaAdminRoleId
    principalId: groupId
    principalType: 'Group'
  }
}


