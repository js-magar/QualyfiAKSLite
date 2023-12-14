param aksClusterName string
param keyVaultUserRoleDefName string
param keyVaultAdminRoleDefName string
param appGWName string
param kvManagedIdentityName string
param keyVaultName string

var kvUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultUserRoleDefName)
var kvAdminRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdminRoleDefName)
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-08-01' existing = {name:aksClusterName}
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-05-01' existing  = {name: appGWName}
resource KVManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing  = {name: kvManagedIdentityName}
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {name: keyVaultName}

resource keyVaultAdminRoleAssignment  'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(KVManagedIdentity.id, kvAdminRoleId, resourceGroup().id)
  properties: {
    roleDefinitionId: kvAdminRoleId
    principalId: KVManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
/*
resource keyVaultSecretsUserApplicationGatewayIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  {
  name: guid(keyVault.id, 'ApplicationGateway', 'keyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: kvUserRoleId
    principalType: 'ServicePrincipal'
    principalId: applicationGateway.identity.principalId
  }
}
*/
resource keyVaultCSIdriverSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, 'CSIDriver', kvUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: kvUserRoleId
    principalType: 'ServicePrincipal'
    principalId: aksCluster.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId
  }
}
