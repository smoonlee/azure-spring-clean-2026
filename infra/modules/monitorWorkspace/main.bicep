param name string
param tags object
param location string


resource monitorWorkspace 'Microsoft.Monitor/accounts@2025-05-03-preview' = {
  name: name
  location: location
  tags: tags
}


@description('The resource ID of the monitor workspace.')
output resourceId string = monitorWorkspace.id
