param appGatewaySubnetName string
param appGatewayPIPName string
param appGatewayName string
param virtualNetworkName string
param costSaving bool
param prefix string = 'aks-jm'

param location string
var appGWSku = costSaving ? 'Standard_v2' : 'WAF_v2'
var appGWFIPConfigName = 'appGatewayFrontendConfig'
var appGWFPortName = 'frontendHttpPort80'
var appGWhttpListenerName='appGWHttpListener'
var appGWBAddressPoolName='backendAddressPool'
var appGWBHttpSettingsName = 'backendHttpPort80'
var wafPolicyName = '${prefix}-waf-agw-${location}-001'
var wafPolicyFileUploadLimitInMb = 100
var wafPolicyMaxRequestBodySizeInKb = 128
var wafPolicyRequestBodyCheck = true
var wafPolicyRuleSetType = 'OWASP'
var wafPolicyRuleSetVersion = '3.2'


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: virtualNetworkName
}
resource AppGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: appGatewaySubnetName,parent: virtualNetwork}
resource appGatewayPIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: appGatewayPIPName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-05-01' = if(!costSaving){
  name: wafPolicyName
  location: location
  properties: {
    policySettings: {
      requestBodyCheck: wafPolicyRequestBodyCheck
      maxRequestBodySizeInKb: wafPolicyMaxRequestBodySizeInKb
      fileUploadLimitInMb: wafPolicyFileUploadLimitInMb
      state: 'Enabled'
      mode: 'Detection'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: wafPolicyRuleSetType
          ruleSetVersion: wafPolicyRuleSetVersion
        }
      ]
    }
  }
}
resource appGateway 'Microsoft.Network/applicationGateways@2023-05-01' = if(!costSaving){
  name: appGatewayName
  location: location
  properties:{
    sku: {
      name: appGWSku
      tier: appGWSku
    }
    backendAddressPools:[
      {
        name:appGWBAddressPoolName
      }
    ]
    backendHttpSettingsCollection:[
      {
        name:appGWBHttpSettingsName
        properties:{
          port:80
          protocol:'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
        }
      }
    ]
    frontendIPConfigurations:[
      {
        name:appGWFIPConfigName
        properties:{
          publicIPAddress:{
            id:appGatewayPIP.id
          }
        }
      }
    ]
    frontendPorts:[
      {
        name:appGWFPortName
        properties:{
          port:80
        }
      }
    ]
    gatewayIPConfigurations:[
      {
        name:'appGatewayIPConfig'
        properties:{
          subnet:{
            id:AppGatewaySubnet.id
          }
        }
      }
    ]
    httpListeners:[
      {
          name:appGWhttpListenerName
          properties:{
            frontendIPConfiguration:{
              id:resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, appGWFIPConfigName)
            }
            frontendPort:{
              id:resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, appGWFPortName)
            }
            protocol:'Http'
          }
      }
    ]
    requestRoutingRules:[
      {
        name:'appGWRoutingRule'
        properties:{
          ruleType:'Basic'
          priority: 1000
          httpListener:{
            id:resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, appGWhttpListenerName)
          }
          backendAddressPool:{
            id:resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, appGWBAddressPoolName)
          }
          backendHttpSettings:{
            id:resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, appGWBHttpSettingsName)
          }

        }
      }
    ]
    probes: [
      {
        name: 'defaultHttpProbe'
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
        }
      }
      {
        name: 'defaultHttpsProbe'
        properties: {
          protocol: 'Https'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
        }
      }
    ]
    autoscaleConfiguration:{
      minCapacity:0
      maxCapacity:10
    }
    firewallPolicy: {
      id: wafPolicy.id
    }
  }
}
resource appGatewayCS 'Microsoft.Network/applicationGateways@2023-05-01'  = if(costSaving){
  name: appGatewayName
  location: location
  properties:{
    sku: {
      name: appGWSku
      tier: appGWSku
    }
    backendAddressPools:[
      {
        name:appGWBAddressPoolName
      }
    ]
    backendHttpSettingsCollection:[
      {
        name:appGWBHttpSettingsName
        properties:{
          port:80
          protocol:'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
        }
      }
    ]
    frontendIPConfigurations:[
      {
        name:appGWFIPConfigName
        properties:{
          publicIPAddress:{
            id:appGatewayPIP.id
          }
        }
      }
    ]
    frontendPorts:[
      {
        name:appGWFPortName
        properties:{
          port:80
        }
      }
    ]
    gatewayIPConfigurations:[
      {
        name:'appGatewayIPConfig'
        properties:{
          subnet:{
            id:AppGatewaySubnet.id
          }
        }
      }
    ]
    httpListeners:[
      {
          name:appGWhttpListenerName
          properties:{
            frontendIPConfiguration:{
              id:resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, appGWFIPConfigName)
            }
            frontendPort:{
              id:resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, appGWFPortName)
            }
            protocol:'Http'
          }
      }
    ]
    requestRoutingRules:[
      {
        name:'appGWRoutingRule'
        properties:{
          ruleType:'Basic'
          priority: 1000
          httpListener:{
            id:resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, appGWhttpListenerName)
          }
          backendAddressPool:{
            id:resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, appGWBAddressPoolName)
          }
          backendHttpSettings:{
            id:resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, appGWBHttpSettingsName)
          }

        }
      }
    ]
    probes: [
      {
        name: 'defaultHttpProbe'
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
        }
      }
      {
        name: 'defaultHttpsProbe'
        properties: {
          protocol: 'Https'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
        }
      }
    ]
    autoscaleConfiguration:{
      minCapacity:0
      maxCapacity:10
    }
  }
}
output appGatwayId string = costSaving ? appGatewayCS.id : appGateway.id
output appGatwayName string = costSaving ? appGatewayCS.name : appGateway.name
