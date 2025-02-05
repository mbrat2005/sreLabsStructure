using 'main.bicep'

param labInstancePrefix = '\${AZURE_ENV_NAME}'

param location = '\${AZURE_LOCATION}'

param principalId = '\${AZURE_PRINCIPAL_ID}'

param deployAzureTableStorage = true
