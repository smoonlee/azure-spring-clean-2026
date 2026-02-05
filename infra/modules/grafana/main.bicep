// Azure Managed Grafana Workspace Bicep module
// Reference: https://learn.microsoft.com/en-us/azure/templates/microsoft.dashboard/grafana

@description('Name of the Azure Managed Grafana instance')
param name string

@description('Azure region for the Grafana resource')
param location string

@description('Tags applied to the Grafana resource')
param tags object = {}

@description('SKU configuration for Grafana')
param sku object = {
  name: 'Standard'
  size: 'X1'
}

@description('Managed identity configuration')
param identity object = {
  type: 'SystemAssigned'
}

var userAssignedIdentities = (identity.?userAssignedIdentities) ?? {}
var hasUserAssignedIdentity = contains(identity.type, 'UserAssigned')
var identityBlock = empty(identity) ? null : (hasUserAssignedIdentity ? {
  type: identity.type
  userAssignedIdentities: userAssignedIdentities
} : {
  type: identity.type
})

@description('Enable public network access')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Enable zone redundancy')
@allowed([
  'Enabled'
  'Disabled'
])
param zoneRedundancy string = 'Disabled'

@description('Grafana major version')
param grafanaMajorVersion string = '11'

@description('Whether the creator will have admin access for the Grafana instance.')
@allowed([
  'Enabled'
  'Disabled'
])
param creatorCanAdmin string = 'Enabled'

@description('Grafana configuration block')
param grafanaConfigurations object = {}

@description('Grafana integrations configuration')
param grafanaIntegrations object = {}

@description('Enterprise configuration options')
param enterpriseConfigurations object = {}

@description('Grafana plugins configuration')
param grafanaPlugins object = {}

resource grafana 'Microsoft.Dashboard/grafana@2025-08-01' = {
  name: name
  location: location
  tags: tags

  sku: {
    name: sku.name
    size: sku.size
  }
  identity: identityBlock
  properties: {
    publicNetworkAccess: publicNetworkAccess
    zoneRedundancy: zoneRedundancy
    grafanaMajorVersion: grafanaMajorVersion
    creatorCanAdmin: creatorCanAdmin
    enterpriseConfigurations: empty(enterpriseConfigurations) ? null : enterpriseConfigurations
    grafanaConfigurations: empty(grafanaConfigurations) ? null : grafanaConfigurations
    grafanaIntegrations: empty(grafanaIntegrations) ? null : grafanaIntegrations
    grafanaPlugins: empty(grafanaPlugins) ? null : grafanaPlugins
  }
}

@description('Resource ID of the created Grafana instance.')
output grafanaResourceId string = grafana.id

@description('Endpoint URL of the created Grafana instance.')
output grafanaEndpoint string = grafana.properties.endpoint

@description('System-assigned managed identity principalId (empty when identity is not enabled).')
output systemAssignedPrincipalId string = (grafana.identity.?principalId) ?? ''
