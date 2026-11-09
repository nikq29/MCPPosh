// MCPPosh on Azure Container Apps
//
// Creates: Log Analytics workspace, storage account with an Azure Files share (the knowledge
// base storage), a Container Apps environment with the share mounted at /data, and the
// MCPPosh container app with HTTPS ingress and an API key.
//
// Deploy with deploy.ps1 or:
//   az deployment group create -g <rg> -f main.bicep -p image=<image> apiKey=<key>

targetScope = 'resourceGroup'

@description('Base name for all resources (lowercase letters, digits and hyphens).')
@minLength(3)
@maxLength(20)
param name string = 'mcpposh'

@description('Azure region.')
param location string = resourceGroup().location

@description('Container image, e.g. ghcr.io/<owner>/mcpposh:latest or <registry>.azurecr.io/mcpposh:0.1.0.')
param image string

@description('API key clients must send as "Authorization: Bearer <key>". Several keys can be separated by commas.')
@secure()
@minLength(16)
param apiKey string

@description('Name of the knowledge base on the share (see Publish-McpKnowledgeBase -RemoteName).')
param knowledgeBase string = 'Default'

@description('Description of the knowledge base, sent to AI agents as server instructions (used when the knowledge base is created).')
param knowledgeBaseDescription string = ''

@description('Enable the add_note tool so AI agents can store new knowledge. Keep maxReplicas at 1 when enabled.')
param allowWrite bool = false

@description('Comma-separated browser origins allowed via CORS (optional).')
param allowedOrigins string = ''

@description('Container registry server for private images, e.g. myregistry.azurecr.io. Leave empty for public images.')
param registryServer string = ''

@description('Registry user name (e.g. the ACR admin user).')
param registryUsername string = ''

@description('Registry password.')
@secure()
param registryPassword string = ''

@description('Minimum replicas. 0 allows scale to zero (cold starts of a few seconds).')
@minValue(0)
@maxValue(10)
param minReplicas int = 1

@description('Maximum replicas.')
@minValue(1)
@maxValue(10)
param maxReplicas int = 1

@description('Quota of the file share in GiB.')
@minValue(1)
param shareQuotaGiB int = 5

var suffix = uniqueString(resourceGroup().id, name)
var storageAccountName = take('${replace(toLower(name), '-', '')}${suffix}', 24)
var shareName = 'mcpposh'
var useRegistry = !empty(registryServer)
var registrySecrets = useRegistry ? [
  {
    name: 'registry-password'
    value: registryPassword
  }
] : []

resource logs 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${name}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storage
  name: 'default'
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: shareName
  properties: {
    shareQuota: shareQuotaGiB
  }
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${name}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
  }
}

resource environmentStorage 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: environment
  name: 'mcpposh-data'
  properties: {
    azureFile: {
      accountName: storage.name
      accountKey: storage.listKeys().keys[0].value
      shareName: share.name
      accessMode: 'ReadWrite'
    }
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
      }
      secrets: concat([
        {
          name: 'api-key'
          value: apiKey
        }
      ], registrySecrets)
      registries: useRegistry ? [
        {
          server: registryServer
          username: registryUsername
          passwordSecretRef: 'registry-password'
        }
      ] : []
    }
    template: {
      containers: [
        {
          name: 'mcpposh'
          image: image
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'MCPPOSH_API_KEY'
              secretRef: 'api-key'
            }
            {
              name: 'MCPPOSH_KNOWLEDGEBASE'
              value: knowledgeBase
            }
            {
              name: 'MCPPOSH_DESCRIPTION'
              value: knowledgeBaseDescription
            }
            {
              name: 'MCPPOSH_ALLOW_WRITE'
              value: string(allowWrite)
            }
            {
              name: 'MCPPOSH_ALLOWED_ORIGINS'
              value: allowedOrigins
            }
          ]
          volumeMounts: [
            {
              volumeName: 'data'
              mountPath: '/data'
            }
          ]
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 2
              periodSeconds: 3
              failureThreshold: 20
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              periodSeconds: 30
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
      volumes: [
        {
          name: 'data'
          storageType: 'AzureFile'
          storageName: environmentStorage.name
          // The container runs as the non-root user 'app' (uid/gid 1654).
          mountOptions: 'uid=1654,gid=1654,dir_mode=0770,file_mode=0660'
        }
      ]
    }
  }
}

@description('MCP endpoint for AI clients.')
output mcpEndpoint string = 'https://${app.properties.configuration.ingress.fqdn}/mcp'

@description('Storage account that holds the knowledge base share (for Publish-McpKnowledgeBase).')
output storageAccountName string = storage.name

@description('Azure Files share mounted at /data.')
output shareName string = share.name
