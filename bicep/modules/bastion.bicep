param location string
param tags object ={tag:'tag'}
param bastionName string
param bastionPIPName string
param bastionSubnetID string

resource bastionPIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: bastionPIPName
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
            id: bastionSubnetID
          }
          publicIPAddress: {
            id: bastionPIP.id
          }
        }
      }
    ]
  }
}
