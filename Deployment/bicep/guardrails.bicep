//Scope
targetScope = 'resourceGroup'
//Parameters and variables
param storageAccountName string
param subscriptionId string
param location string = 'canadacentral'
param kvName string = 'guardrails-kv'
param automationAccountName string = 'guardrails-AC'
param logAnalyticsWorkspaceName string = 'guardrails-LAW'
//var <variable-name> = <variable-value>
var vaultUri = 'https://${kvName}.vault.azure.net/'
var wbConfig1 ='''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "let GR8status=GuardrailsCompliance_CL \r\n| where ControlName_s has \"GUARDRAIL 8:\" and ComplianceStatus_b == false\r\n| summarize NotCompliantCount=count() by ControlName_s, ItemName_s\r\n| extend Status=iif(NotCompliantCount <1, '✔️ ', '❌ ')\r\n| project ControlName=ControlName_s, ['Compliance Status']=Status, ['Item Name']=ItemName_s;\r\nGuardrailsCompliance_CL \r\n| where ControlName_s <> \"GUARDRAIL 8: NETWORK SEGMENTATION AND SEPARATION\"\r\n| summarize Requests = count() by ControlName = ControlName_s ,  ['Item Name'] = ItemName_s , ComplianceStatus_b\r\n| extend  ['Compliance Status'] = iif( ComplianceStatus_b, '✔️ ', '❌ ')\r\n| order by ControlName ,  ['Item Name'], ['Compliance Status']\r\n| project   ControlName ,  ['Item Name'], ['Compliance Status']\r\n| union GR8status",
        "size": 3,
        "timeContext": {
          "durationMs": 3600000
        },
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "table",
        "gridSettings": {
          "hierarchySettings": {
            "treeType": 1,
            "groupBy": [
              "ControlName"
            ],
            "expandTopLevel": true
          },
          "sortBy": [
            {
              "itemKey": "$gen_count_$gen_group_0",
              "sortOrder": 1
            }
          ]
        },
        "sortBy": [
          {
            "itemKey": "$gen_count_$gen_group_0",
            "sortOrder": 1
          }
        ]
      },
      "name": "query - 0"
    }
  ],
  "isLocked": false,
  "fallbackResourceIds": [
'''
var wbConfig2='"/subscriptions/${subscriptionId}/resourceGroups/Guardrail/providers/Microsoft.OperationalInsights/workspaces/${logAnalyticsWorkspaceName}"'
var wbConfig3='''
  ]
}
'''
var wbConfig='${wbConfig1}${wbConfig2}${wbConfig3}'
//Resources:
//KeyVault

resource guardrailsAC 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: automationAccountName
  location: location
  identity: {
     type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: true
    disableLocalAuth: false
    sku: {
        name: 'Basic'
    }
    encryption: {
        keySource: 'Microsoft.Automation'
        identity: {}
    }
  }
}
resource guardrailsKV 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name:  'standard'
    }

    tenantId: guardrailsAC.identity.tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: false
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    vaultUri: vaultUri
    provisioningState: 'Succeeded'
    publicNetworkAccess: 'Enabled'
  }
}

resource guardrailsLogAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}
resource guarrailsWorkbooks 'Microsoft.Insights/workbooks@2021-08-01' = {
location: location
kind: 'shared'
name: guid('guardrails')
properties:{
  displayName: 'Guardrails'
  serializedData: wbConfig
  version: '1.0'
  category: 'workbook'
  sourceId: guardrailsLogAnalytics.id
}

}
//Storage Account
resource guardrailsStorage 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
  }
}
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01'={
  name: '${guardrailsStorage.name}/default'
  properties: {
      cors: {
          corsRules: []
      }
      deleteRetentionPolicy: {
          enabled: false
      }
  }
}

resource container1 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01'={
  name: '${guardrailsStorage.name}/default/guardrailsolutionaccelerator'
  properties: {
    immutableStorageWithVersioning: {
        enabled: false
    }
    denyEncryptionScopeOverride: false
    defaultEncryptionScope: '$account-encryption-key'
    publicAccess: 'None'
}
  dependsOn:[
    blobServices
  ]
}
resource container2 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01'={
  name: '${guardrailsStorage.name}/default/psmodules'
  properties: {
    immutableStorageWithVersioning: {
        enabled: false
    }
    denyEncryptionScopeOverride: false
    defaultEncryptionScope: '$account-encryption-key'
    publicAccess: 'None'
}
  dependsOn:[
    blobServices
  ]
}
