# Guardrails - Setup

## Configuration

Navigate to shell.azure.com and authenticate as a user that has Azure and Azure AD Permissions (To create resources and create SPNs)

If you have more than one subscription, make sure to use `select-azsubscription` to determine to which subscription the components should be deployed to.

Clone repository

` git clone <URL TBD>`

cd to `.\Guardrailssolutionaccelerator\Deployment\bicep`

Edit config-sample.json with `code .\config-sample.json' and adjust parameters as required.

Save the file and exit VSCode.

## Deployment

If the deployment is being done using the Azure Cloud Shell, the currentuserUPN parameter below refers to the user logged in. This is required when using the cloud shell.

Run `.\setup-all.ps1 -configFilePath .\config-sample.json -userId <currentuserUPN>`

## How it works

### Module 8

### Module 9
