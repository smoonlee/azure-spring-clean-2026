targetScope = 'subscription'

@description('Customer Name (e.g., bwc, contoso)')
param customerName string

@description('Azure Region for Deployment')
param location string

@description('Location Short Code (e.g., weu for West Europe)')
param locationShortCode string

@description('Environment Type (e.g., dev, test, prod)')
@allowed(['dev', 'acc', 'prod'])
param environmentType string

@description('Deployed By')
param deployedBy string

@description('Azure Metadata Tags')
param tags object = {
  environmentType: environmentType
  deployedBy: deployedBy
  deployedDate: utcNow('yyyy-MM-dd')
}

param resourceGroupName string = 'rg-${customerName}-asc-vminsights-${locationShortCode}'
param virtualNetworkName string = 'vnet-${customerName}-asc-vminsights-${locationShortCode}'
param networkSecurityGroupName string = 'nsg-${customerName}-asc-${locationShortCode}'
param dataCollectionRuleName string = 'MSVMOtel-${location}-${vmHostName}'

param vmHostName string = 'vm-windows'
param vmUserName string = 'azureuser'

@secure()
param vmUserPassword string = 'P@ssw0rd123!'

//
// Modules
//

module createResourceGroup 'br/public:avm/res/resources/resource-group:0.4.3' = {
  name: 'create-resource-group'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

module createMonitorWorkspace 'modules/monitorWorkspace/main.bicep' = {
  name: 'create-monitor-workspace'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'mon-${customerName}-asc-vminsights-${locationShortCode}'
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createDataCollectionRule 'br/public:avm/res/insights/data-collection-rule:0.10.0' = {
  name: 'create-data-collection-rule'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: dataCollectionRuleName
    location: location
    dataCollectionRuleProperties: {
      kind: 'All'
      dataSources: {
        performanceCountersOTel: [
          {
            streams: [
              'Microsoft-OtelPerfMetrics'
            ]
            samplingFrequencyInSeconds: 60
            counterSpecifiers: [
              'system.filesystem.usage'
              'system.disk.io'
              'system.disk.operation_time'
              'system.disk.operations'
              'system.memory.usage'
              'system.network.io'
              'system.cpu.time'
              'system.network.dropped'
              'system.network.errors'
              'system.uptime'
            ]
            name: 'OtelDataSource'
          }
        ]
      }
      destinations: {
        monitoringAccounts: [
          {
            accountResourceId: createMonitorWorkspace.outputs.resourceId
            name: 'MonitoringAccountDestination'
          }
        ]
      }
      dataFlows: [
        {
          streams: [
            'Microsoft-OtelPerfMetrics'
          ]
          destinations: [
            'MonitoringAccountDestination'
          ]
        }
      ]
    }
    tags: tags
  }
  dependsOn: [
    createMonitorWorkspace
  ]
}

module createNetworkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.2' = {
  name: 'create-network-security-group'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: networkSecurityGroupName
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createVirtualNetwork 'br/public:avm/res/network/virtual-network:0.7.2' = {
  name: 'create-virtual-network'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [
      '10.0.0.0/24'
    ]
    subnets: [
      {
        name: 'snet-asc-vm-insights'
        addressPrefix: '10.0.0.0/24'
        networkSecurityGroupResourceId: createNetworkSecurityGroup.outputs.resourceId
      }
    ]
    tags: tags
  }
  dependsOn: [
    createNetworkSecurityGroup
  ]
}

module createVirtualMachine 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  name: 'create-virtual-machine'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: vmHostName
    adminUsername: vmUserName
    adminPassword: vmUserPassword
    location: location
    osType: 'Windows'
    vmSize: 'Standard_D2ls_v6'
    availabilityZone: -1
    bootDiagnostics: true
    secureBootEnabled: true
    encryptionAtHost: true
    vTpmEnabled: true
    securityType: 'TrustedLaunch'
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition-hotpatch'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            pipConfiguration: {
              name: '${vmHostName}-pip-01'
            }
            subnetResourceId: createVirtualNetwork.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: '-nic-01'
        enableAcceleratedNetworking: true
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    extensionMonitoringAgentConfig: {
      enabled: true
      dataCollectionRuleAssociations: [
        {
          dataCollectionRuleResourceId: createDataCollectionRule.outputs.resourceId
          name: 'SendMetricsToLAW'
        }
      ]
    }
    tags: tags
  }
  dependsOn: [
    createVirtualNetwork
    createDataCollectionRule
  ]
}
