param location string
param bastionSubnetName string
param vnetName string
param tags object ={tag:'tag'}
param bastionName string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {name: vnetName}
resource BastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: bastionSubnetName,parent: virtualNetwork}


resource bastionPIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${bastionName}'
  location: location
  tags:tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}
resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: bastionName
  location:location
  tags:tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableIpConnect: true
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: BastionSubnet.id
          }
          publicIPAddress: {
            id: bastionPIP.id
          }
        }
      }
    ]
  }
}
