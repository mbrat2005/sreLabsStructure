targetScope = 'subscription'

param location string = 'southeastasia'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'myResourceGroup'
  location: location
}
