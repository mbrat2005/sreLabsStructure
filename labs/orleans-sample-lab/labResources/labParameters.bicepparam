using 'main.bicep'

param environmentName = '\${AZURE_ENV_NAME}'

param location = '\${AZURE_LOCATION}'

param principalId = '\${AZURE_PRINCIPAL_ID}'

param deployAzureCosmosDBNoSQL = '\${DEPLOY_AZURE_COSMOS_DB_NOSQL}'

param deployAzureTableStorage = '\${DEPLOY_AZURE_TABLE_STORAGE}'
