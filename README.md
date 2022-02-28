# Guardrails - Setup

## Configuration

Navigate to shell.azure.com and authenticate as a user that has Azure and Azure AD Permissions (To assign permissions to the Automation Account Managed Identity)

Clone repository

` git clone <URL TBD>`

cd to `.\Guardrailssolutionaccelerator\Deployment\bicep`

Edit config.json with `code .\config.json' and adjust parameters as required.

Save the file and exit VSCode.

## Deployment

If the deployment is being done using the Azure Cloud Shell, the currentuserUPN parameter below refers to the user logged in. This is required when using the cloud shell.

The solution will deploy new resources.

Run `.\setup.ps1 -configFilePath .\config-sample.json -userId <currentuserUPN>`

Alternatively, these parameters can be used to leverage existing KeyVault and Log Analytics resources:

`$existingKeyVaultName` : the name of an existing Keyvault. If provided, the RG below must be specified and the content of config.json will be ignored.

`$existingKeyVaultRG` : the resource group containing the Keyvault above.

`$existingWorkspaceName`: the name of an existing Log Analytics Workspace. If provided, the RG below must be specified and the content of config.json will be ignored. Also, for now, the Workbook will not be deployed automatically and will have to be added manually to the existing workspace.

`$existingWorkSpaceRG`: the resource group containing the Log Analytics Workspace above.

`$skipDeployment`: the setup script will run everything but the Azure Resources deployment (for debug/testing only)

## How it works

### Module 8

### Module 9
