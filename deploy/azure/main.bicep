// PSMcpKnowledgeBase on Azure Container Apps
//
// Creates: Log Analytics workspace, storage account with an Azure Files share (the knowledge
// base storage), a Container Apps environment with the share mounted at /data, and the
// PSMcpKnowledgeBase container app with HTTPS ingress, an API key and/or Microsoft Entra ID sign-in (OAuth).
//
// Deploy with deploy.ps1, the "Deploy to Azure" button (azuredeploy.json) or:
//   az deployment group create -g <rg> -f main.bicep -p apiKey=<key>
// After changing this file, regenerate azuredeploy.json with the Bicep version pinned in
// .github/workflows/build.yml: bicep build main.bicep --outfile azuredeploy.json

targetScope = 'resourceGroup'

@description('Base name for all resources (lowercase letters, digits and hyphens).')
@minLength(3)
@maxLength(20)
param name string = 'psmcpkb'

@description('Azure region.')
param location string = resourceGroup().location

@description('Container image, e.g. ghcr.io/nikq29/psmcpkb:0.1.1 (a fixed version) or <registry>.azurecr.io/psmcpkb:0.1.0.')
param image string = 'ghcr.io/nikq29/psmcpkb:latest'

@description('API key clients must send as "Authorization: Bearer <key>" (at least 16 characters). Several keys can be separated by commas. Leave empty only with oauthClientId or allowAnonymous; without any of them the server does not start.')
@secure()
param apiKey string = ''

@description('Name of the knowledge base on the share (see Publish-McpKnowledgeBase -RemoteName).')
param knowledgeBase string = 'Default'

@description('Description of the knowledge base, sent to AI agents as server instructions (used when the knowledge base is created).')
param knowledgeBaseDescription string = ''

@description('Enable the add_note tool so AI agents can store new knowledge. Keep maxReplicas at 1 when enabled.')
param allowWrite bool = false

@description('Accept requests without API key or token. Only behind a gateway that authenticates every request, e.g. Container Apps authentication or API Management.')
param allowAnonymous bool = false

@description('Client ID of a Microsoft Entra app registration in this tenant. Clients can then sign in with OAuth in addition to the API key. Empty: OAuth off.')
param oauthClientId string = ''

@description('Scope the app registration exposes and the access tokens must contain (short name, e.g. access_as_user).')
param oauthScope string = 'access_as_user'

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
var shareName = 'psmcpkb'
var useRegistry = !empty(registryServer)
var useApiKey = !empty(apiKey)
var apiKeySecrets = useApiKey ? [
  {
    name: 'api-key'
    value: apiKey
  }
] : []
var apiKeyEnv = useApiKey ? [
  {
    name: 'PSMCPKB_API_KEY'
    secretRef: 'api-key'
  }
] : []
// Tokens of the tenant this template is deployed to; v2 tokens carry the client ID, v1 tokens the api:// URI.
var oauthEnv = empty(oauthClientId) ? [] : [
  {
    name: 'PSMCPKB_OAUTH_ISSUER'
    value: '${az.environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
  }
  {
    name: 'PSMCPKB_OAUTH_AUDIENCE'
    value: '${oauthClientId},api://${oauthClientId}'
  }
  {
    name: 'PSMCPKB_OAUTH_SCOPE'
    value: 'api://${oauthClientId}/${oauthScope}'
  }
]
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
  name: 'psmcpkb-data'
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
      secrets: concat(apiKeySecrets, registrySecrets)
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
          name: 'psmcpkb'
          image: image
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: concat(apiKeyEnv, [
            {
              name: 'PSMCPKB_KNOWLEDGEBASE'
              value: knowledgeBase
            }
            {
              name: 'PSMCPKB_DESCRIPTION'
              value: knowledgeBaseDescription
            }
            {
              name: 'PSMCPKB_ALLOW_WRITE'
              value: string(allowWrite)
            }
            {
              name: 'PSMCPKB_ALLOW_ANONYMOUS'
              value: string(allowAnonymous)
            }
            {
              name: 'PSMCPKB_ALLOWED_ORIGINS'
              value: allowedOrigins
            }
          ], oauthEnv)
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
