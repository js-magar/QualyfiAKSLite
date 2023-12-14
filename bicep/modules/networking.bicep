param location string
param natGatewayPIPName string
param natGatewayName string
param virtualNetworkName string
param vnetAddressPrefix string
param systemPoolSubnetName string
param systemPoolSubnetAddressPrefix string
param appPoolSubnetName string
param appPoolSubnetAddressPrefix string
param podSubnetName string
param podSubnetAddressPrefix string
param appGatewaySubnetName string
param appGatewaySubnetAddressPrefix string
param bastionSubnetName string
param bastionSubnetAddressPrefix string
param appgwbastionPrefix string

var natGatewayID = natGateway.id 

var systemAddress = '${vnetAddressPrefix}.${systemPoolSubnetAddressPrefix}.0.0/16'
var appAddress = '${vnetAddressPrefix}.${appPoolSubnetAddressPrefix}.0.0/16'
var podAddress = '${vnetAddressPrefix}.${podSubnetAddressPrefix}.0.0/16'
var appGatewayAddress = '${vnetAddressPrefix}.${appgwbastionPrefix}.${appGatewaySubnetAddressPrefix}.0/24'
var bastionAddress = '${vnetAddressPrefix}.${appgwbastionPrefix}.${bastionSubnetAddressPrefix}.0/24'

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
      { name: systemPoolSubnetName
        properties: {
          addressPrefix: systemAddress
          natGateway:{
            id:natGatewayID
          }
        }
      }
      { name: appPoolSubnetName
        properties: {
          addressPrefix: appAddress
          natGateway:{
            id:natGatewayID
          }
        }
      }
      { name: podSubnetName
        properties: {
          addressPrefix: podAddress
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
      { name: appGatewaySubnetName
        properties: {
          addressPrefix: appGatewayAddress
        }
      }
      { name: bastionSubnetName
        properties: {
          addressPrefix: bastionAddress
        }
      }
    ]
  }
}
resource systemPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: systemPoolSubnetName,parent: virtualNetwork}
resource appPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: appPoolSubnetName,parent: virtualNetwork}
resource podPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: podSubnetName,parent: virtualNetwork}
resource appGatewayPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: appGatewaySubnetName,parent: virtualNetwork}
resource bastionPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: bastionSubnetName,parent: virtualNetwork}

output systemPoolSubnetID string = systemPoolSubnet.id
output appPoolSubnetID string = appPoolSubnet.id
output podPoolSubnetID string = podPoolSubnet.id
output appGatewaySubnetID string = appGatewayPoolSubnet.id
output bastionSubnetID string = bastionPoolSubnet.id
