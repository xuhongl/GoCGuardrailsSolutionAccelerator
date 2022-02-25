//Scope
targetScope = 'resourceGroup'
//Parameters and variables
param storageAccountName string
param subscriptionId string
param location string = 'canadacentral'
param kvName string = 'guardrails-kv'
param automationAccountName string = 'guardrails-AC'
param logAnalyticsWorkspaceName string = 'guardrails-LAW'
param PBMMPolicyID string = '4c4a5f27-de81-430b-b4e5-9cbd50595a87'
param deployKV bool = true
param deployLAW bool = true
//var <variable-name> = <variable-value>
var containername = 'guardrailsstorage'
var vaultUri = 'https://${kvName}.vault.azure.net/'
var rg=resourceGroup().name
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
    },
    {
      "type": 1,
      "content": {
        "json": "## Details",
        "style": "info"
      },
      "name": "Details Title"
    },
    {
      "type": 11,
      "content": {
        "version": "LinkItem/1.0",
        "style": "tabs",
        "links": [
          {
            "id": "6a683959-7ed3-42b1-a509-3cdcd18017cf",
            "cellValue": "selectedTab",
            "linkTarget": "parameter",
            "linkLabel": "GUARDRAIL 1",
            "subTarget": "gr1",
            "style": "link"
          },
          {
            "id": "6a683959-7fd3-42b1-a509-3cdcd18017cf",
            "cellValue": "selectedTab",
            "linkTarget": "parameter",
            "linkLabel": "GUARDRAIL 2",
            "subTarget": "gr2",
            "style": "link"
          },
          {
            "id": "6a683359-7ed3-42b1-a509-3cdcd18017cf",
            "cellValue": "selectedTab",
            "linkTarget": "parameter",
            "linkLabel": "GUARDRAIL 3",
            "subTarget": "gr3",
            "style": "link"
          },
          {
            "id": "6a383959-7ed3-42b1-a509-3cdcd18017cf",
            "cellValue": "selectedTab",
            "linkTarget": "parameter",
            "linkLabel": "GUARDRAIL 4",
            "subTarget": "gr4",
            "style": "link"
          },
          {
            "id": "6b683959-7ed3-42b1-a509-3cdcd18017cf",
            "cellValue": "selectedTab",
            "linkTarget": "parameter",
            "linkLabel": "GUARDRAIL 5",
            "subTarget": "gr5",
            "style": "link"
          },
          {
            "id": "6a683959-7fd3-42b1-a509-3cdcd18017cf",
            "cellValue": "selectedTab",
            "linkTarget": "parameter",
            "linkLabel": "GUARDRAIL 6",
            "subTarget": "gr6",
            "style": "link"
          },
          {
            "id": "6a683959-7ed3-42b1-a509-3cfcd18017cf",
            "cellValue": "selectedTab",
            "linkTarget": "parameter",
            "linkLabel": "GUARDRAIL 7",
            "subTarget": "gr7",
            "style": "link"
          },
          {
            "id": "4b2de2e9-a9c7-486c-a524-7da0e8f44d26",
            "cellValue": "selectedTab",
            "linkTarget": "parameter",
            "linkLabel": "GUARDRAIL 8",
            "subTarget": "gr8",
            "style": "link"
          },
          {
            "id": "40243b3d-3037-482b-959b-d95c1b4b2014",
            "cellValue": "selectedTab",
            "linkTarget": "parameter",
            "linkLabel": "GUARDRAIL 9",
            "subTarget": "gr9",
            "style": "link"
          }
        ]
      },
      "name": "links - 1"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "GuardrailsCompliance_CL\r\n| where ControlName_s has \"GUARDRAIL 8:\" \r\n| project SubnetName=SubnetName_s, Status=iif(tostring(ComplianceStatus_b)==\"True\", '✔️ ', '❌ '), Comments=Comments_s\r\n| sort by Status asc",
        "size": 0,
        "timeContext": {
          "durationMs": 3600000
        },
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "gridSettings": {
          "hierarchySettings": {
            "treeType": 1,
            "groupBy": [
              "Status"
            ]
          }
        }
      },
      "conditionalVisibility": {
        "parameterName": "selectedTab",
        "comparison": "isEqualTo",
        "value": "gr8"
      },
      "name": "query - 2"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "GuardrailsCompliance_CL\r\n| where ControlName_s has \"GUARDRAIL 9:\" \r\n| project ['VNet Name']=VNETName_s, Status=iif(tostring(ComplianceStatus_b)==\"True\", '✔️ ', '❌ '), Comments=Comments_s\r\n",
        "size": 0,
        "timeContext": {
          "durationMs": 3600000
        },
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "conditionalVisibility": {
        "parameterName": "selectedTab",
        "comparison": "isEqualTo",
        "value": "gr9"
      },
      "name": "query - 3"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "GuardrailsCompliance_CL\r\n| where ControlName_s has \"GUARDRAIL 1\"\r\n|project ItemName=ItemName_s, Comments=Comments_s, Status=iif(tostring(ComplianceStatus_b)==\"True\", '✔️ ', '❌ ')",
        "size": 0,
        "timeContext": {
          "durationMs": 3600000
        },
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "conditionalVisibility": {
        "parameterName": "selectedTab",
        "comparison": "isEqualTo",
        "value": "gr1"
      },
      "name": "Gr1"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "GuardrailsCompliance_CL\r\n| where ControlName_s has \"GUARDRAIL 4\"\r\n|project ItemName=ItemName_s, Comments=Comments_s, Status=iif(tostring(ComplianceStatus_b)==\"True\", '✔️ ', '❌ ')",
        "size": 0,
        "timeContext": {
          "durationMs": 3600000
        },
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "conditionalVisibility": {
        "parameterName": "selectedTab",
        "comparison": "isEqualTo",
        "value": "gr4"
      },
      "name": "query - 6 - Copy"
    }
  ],
  "fallbackResourceIds": [
'''
var wbConfig2='"/subscriptions/${subscriptionId}/resourceGroups/${rg}/providers/Microsoft.OperationalInsights/workspaces/${logAnalyticsWorkspaceName}"'
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
  resource OMSModule 'modules' ={
    name: 'OMSIngestionAPI'
    properties: {
      contentLink: {
        uri: 'https://devopsgallerystorage.blob.core.windows.net/packages/omsingestionapi.1.6.0.nupkg'
        version: '1.6.0'
      }
    }
  }
  resource AzureGraph 'modules' ={
    name: 'AzureGraph'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/AzureGraph.zip'
        version: '1.0.0'
      }
    }
  }
  resource module1 'modules' ={
    name: 'Check-BreackGlassAccountOwnersInformation'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-BreackGlassAccountOwnersInformation.zip'
        version: '1.0.0'
      }
    }
  }
resource module2 'modules' ={
    name: 'Check-BreakGlassAccountIdentityProtectionLicense'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-BreakGlassAccountIdentityProtectionLicense.zip'
        version: '1.0.0'
      }
    }
  }
resource module3 'modules' ={
    name: 'Check-BreakGlassAccountProcedure'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-BreakGlassAccountProcedure.zip'
        version: '1.0.0'
      }
    }
  }
resource module4 'modules' ={
    name: 'Check-DeprecatedAccounts'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-DeprecatedAccounts.zip'
        version: '1.0.0'
      }
    }
  }
resource module5 'modules' ={
    name: 'Check-ExternalAccounts'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-ExternalAccounts.zip'
        version: '1.0.0'
      }
    }
  }
resource module6 'modules' ={
    name: 'Check-GuardRailsConditionalAccessPolicie'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-GuardRailsConditionalAccessPolicie.zip'
        version: '1.0.0'
      }
    }
  }
resource module7 'modules' ={
    name: 'Check-MonitorAccount'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-MonitorAccount.zip'
        version: '1.0.0'
      }
    }
  }
resource module8 'modules' ={
    name: 'Check-PBMMPolicy'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-PBMMPolicy.zip'
        version: '1.0.0'
      }
    }
  }
resource module9 'modules' ={
    name: 'Check-SubnetComplianceStatus'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-SubnetComplianceStatus.zip'
        version: '1.0.0'
      }
    }
  }
resource module10 'modules' ={
    name: 'Check-VNetComplianceStatus'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Check-VNetComplianceStatus.zip'
        version: '1.0.0'
      }
    }
  }
resource module11 'modules' ={
    name: 'Detect-UserBGAUsersAuthMethods'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Detect-UserBGAUsersAuthMethods.zip'
        version: '1.0.0'
      }
    }
  }
resource module12 'modules' ={
    name: 'Get-AzureADLicenseType'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Get-AzureADLicenseType.zip'
        version: '1.0.0'
      }
    }
  }
resource module13 'modules' ={
    name: 'Get-Tags'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Get-Tags.zip'
        version: '1.0.0'
      }
    }
  }
resource module14 'modules' ={
    name: 'Validate-BreakGlassAccount'
    properties: {
      contentLink: {
        uri: 'https://guardrail.blob.core.windows.net/psmodules/Validate-BreakGlassAccount.zip'
        version: '1.0.0'
      }
    }
  }
  
  resource variable1 'variables' = {
    name: 'KeyvaultName'
    properties: {
        isEncrypted: false
        value: '"${guardrailsKV.name}"'
    }
  }
  
  resource variable2 'variables' = {
    'name': 'WorkSpaceID'
    'properties': {
        'isEncrypted': false
        'value': '"${guardrailsLogAnalytics.properties.customerId}"'
    }
  }
  resource variable3 'variables' = {
    'name': 'LogType'
    'properties': {
        'isEncrypted': false
        'value': '"GuardrailsCompliance"'
    }
  }
  resource variable4 'variables' = {
    'name': 'PBMMPolicyID'
    'properties': {
        'isEncrypted': false
        'value': '"${PBMMPolicyID}"'
    }
  }
  resource variable5 'variables' = {
    'name': 'GuardrailWorkspaceIDKeyName'
    'properties': {
        'isEncrypted': false
        'value': '"WorkSpaceKey"'
    }
  }
  resource variable6 'variables' = {
    'name': 'StorageAccountName'
    'properties': {
        'isEncrypted': false
        'value': '"${guardrailsStorage.name}"'
    }
  }
  resource variable7 'variables' = {
    'name': 'ContainerName'
    'properties': {
        'isEncrypted': false
        'value': '"${containername}"'
    }
  }
  resource variable8 'variables' = {
    'name': 'ResourceGroupName'
    'properties': {
        'isEncrypted': false
        'value': '"${resourceGroup().name}"'
    }
  }
}

resource guardrailsKV 'Microsoft.KeyVault/vaults@2021-06-01-preview' = if (deployKV) {
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

resource guardrailsLogAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = if (deployLAW) {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource guarrailsWorkbooks 'Microsoft.Insights/workbooks@2021-08-01' = if (deployLAW) {
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
  resource blobServices 'blobServices'={
    name: 'default'
    properties: {
        cors: {
            corsRules: []
        }
        deleteRetentionPolicy: {
            enabled: false
        }
    }
    resource container1 'containers'={
      name: containername
      properties: {
        immutableStorageWithVersioning: {
            enabled: false
        }
        denyEncryptionScopeOverride: false
        defaultEncryptionScope: '$account-encryption-key'
        publicAccess: 'None'
      }
    }
    resource container2 'containers'={
      name: 'psmodules'
      properties: {
        immutableStorageWithVersioning: {
            enabled: false
        }
        denyEncryptionScopeOverride: false
        defaultEncryptionScope: '$account-encryption-key'
        publicAccess: 'None'
      }
    }
  }
}


