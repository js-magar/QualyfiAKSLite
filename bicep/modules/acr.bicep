param acrName string
param logAnalyticsName string
param location string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name:logAnalyticsName
}
resource acrResource 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  location: location
  name:acrName
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
  }
}
resource acrDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    scope: acrResource
    name: 'diagnostics'
    properties: {
      workspaceId: logAnalyticsWorkspace.id
      metrics: [
        {
          timeGrain: 'PT1M'
          category: 'AllMetrics'
          enabled: true
        }
      ]
      logs: [
        {
          category: 'ContainerRegistryRepositoryEvents'
          enabled: true
        }
        {
          category: 'ContainerRegistryLoginEvents'
          enabled: true
        }
    ]
  }
}
