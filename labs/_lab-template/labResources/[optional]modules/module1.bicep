
param location string

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'nsg'
  location: location
  properties: {
    securityRules: []
  }
}
