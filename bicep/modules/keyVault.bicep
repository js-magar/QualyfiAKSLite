param location string
param keyVaultName string
var kvIdentityUserDefinedManagedIdentityName = 'mi-${keyVaultName}'

resource KVManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: kvIdentityUserDefinedManagedIdentityName
  location: location
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enableSoftDelete: false
  }
}

output kvIdentityUserDefinedManagedIdentityName string = KVManagedIdentity.name
