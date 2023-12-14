
param grafanaName string
param groupId string
param prometheusName string
param monitoringReaderRoleDefName string
param monitoringDataReaderRoleDefName string
param grafanaAdminRoleDefName string

var monitoringReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringReaderRoleDefName)
var monitoringDataReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringDataReaderRoleDefName)
var grafanaAdminRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', grafanaAdminRoleDefName)

resource azureMonitorWorkspace 'Microsoft.Monitor/accounts@2023-04-03' existing = {name:prometheusName}
resource managedGrafana 'Microsoft.Dashboard/grafana@2022-08-01' existing = {name: grafanaName}

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
