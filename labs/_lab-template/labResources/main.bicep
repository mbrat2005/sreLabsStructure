targetScope = 'subscription'

@description('Location for all resources.')
param location string

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'myResourceGroup'
  location: location
  tags: {
    environment: 'dev'
  }
}

module module1 '[optional]modules/module1.bicep' = {
  name: 'module1'
  scope: resourceGroup(rg.name)
  params: {
    location: location
  }
}
