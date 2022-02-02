param (
        [Parameter(Mandatory=$true)]
        [string]
        $configFilePath,
        [Parameter(Mandatory=$false)]
        [string]
        $userId
    )
#region Configuration and initialization
import-module .\blob-functions.psm1

#Configuration Variables
$randomstoragechars=-join ((97..122) | Get-Random -Count 4 | % {[char]$_})
$config=get-content $configFilePath | convertfrom-json

$keyVaultName=$config.keyVaultName
$resourcegroup=$config.resourcegroup
$region=$config.region
$storageaccountName="$($config.storageaccountName)$randomstoragechars"
$logAnalyticsworkspaceName=$config.logAnalyticsworkspaceName
$autoMationAccountName=$config.autoMationAccountName
$spnName=$config.spnName
$bga1=$config.bga1 #Break glass account 1
$bga2=$config.bga2 #Break glass account 2
$FirstBreakGlassUPN=$config.FirstBreakGlassUPN 
$SecondBreakGlassUPN=$config.SecondBreakGlassUPN

#Other Variables
$mainRunbookName="main"
$mainRunbookPath='..\..\GUARDRAIL COMMON\'
$mainRunbookDescription="Guardrails Main Runbook"

#Tests if logged in:
$sub = Get-AzSubscription -ErrorAction SilentlyContinue
if(-not($sub))
{
    Connect-AzAccount
}
#endregion
#Storage verification
if ((Get-AzStorageAccountNameAvailability -Name $storageaccountName).NameAvailable -eq $false)
{
    Write-Error "Storage account $storageaccountName not available."
    break
}
if ($storageaccountName.Length -gt 24 -or $storageaccountName.Length -lt 3)
{
    Write-Error "Storage account name must be between 3 and 24 lowercase characters."
    break
}
#endregion

#before deploying anything, check if current user can be found.
Write-Verbose "Adding current user as a Keyvault administrator (for setup)."
if ($userId -eq "")
{
    $currentUserId=(get-azaduser -UserPrincipalName (Get-AzAccessToken).UserId).Id 
}
else
{
    $currentUserId=(get-azaduser -UserPrincipalName $userId).Id
}
if ($currentUserId -eq $null)
{
    Write-Error "Error: no current user could be found in current Tenant. Context: $((Get-AzAccessToken).UserId). Override specified: $userId."
    break;
}

#region  Template Deployment
#
$parameterTemplate=get-content .\parameters_template.json
$parameterTemplate=$parameterTemplate.Replace("%kvName%",$keyVaultName)
$parameterTemplate=$parameterTemplate.Replace("%location%",$region)
$parameterTemplate=$parameterTemplate.Replace("%storageAccountName%",$storageaccountName)
$parameterTemplate=$parameterTemplate.Replace("%logAnalyticsWorkspaceName%",$logAnalyticsworkspaceName)
$parameterTemplate=$parameterTemplate.Replace("%automationAccountName%",$autoMationAccountName)
$parameterTemplate=$parameterTemplate.Replace("%subscriptionId%",(Get-AzContext).Subscription.Id)
$parameterTemplate | out-file .\parameters.json -Force
#endregion

#region bicep deployment
Write-Verbose "Creating $resourceGroup in $region location."
try {
    New-AzResourceGroup -Name $resourceGroup -Location $region
}
catch { Write-error "Error creating resource group. "}
Write-Verbose "Deploying solution through bicep."
try { 
    New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup -Name "guardraildeployment$(get-date -format "ddmmyyHHmmss")" -TemplateParameterFile .\parameters.json -TemplateFile .\guardrails.bicep
}
catch {
    Write-error "Error deploying solution to Azure."
}
#endregion
#Add current user as a Keyvault administrator (for setup)
$kv=Get-AzKeyVault -ResourceGroupName $resourceGroup -VaultName $keyVaultName
New-AzRoleAssignment -ObjectId $currentUserId -RoleDefinitionName "Key Vault Administrator" -Scope $kv.ResourceId
#region Module import
#Copy all modules to storage account
# Uploads all files to the storage account just created.
Write-output "Uploading modules to storage account."
Get-Item "..\*.zip" | ForEach-Object { copy-toBlob -FilePath $_.FullName -storageaccountName $storageaccountName -resourcegroup $resourcegroup } 
#Import using powershell
$context=New-AzStorageContext -StorageAccountName $storageaccountName -StorageAccountKey (Get-AzStorageAccountKey -ResourceGroupName $resourcegroup -Name $storageaccountName)[0].Value
$blobs=get-blobs -resourceGroup $resourceGroup -storageAccountName $storageaccountName
Write-output "Importing $($blobs.Count) modules."
foreach ($blob in $blobs)
{
    Write-verbose "Importing module $($blob.Name)"
    [uri]$uri=New-AzStorageBlobSASToken -BlobBaseClient $blob.BlobBaseClient -CloudBlob $blob.ICloudBlob -Permission r -ExpiryTime (get-date).AddMinutes(15) -FullUri -Context $context
    Import-AzAutomationModule -ResourceGroupName $resourceGroup -AutomationAccountName $autoMationAccountName -ContentLinkUri $uri -Name $blob.Name.replace(".zip","")
}
#endregion

#region Secret Setup

#Write-Output "Sleeping 30 seconds to allow for permissions to be propagated."
#Start-Sleep -Seconds 30
# Adds keyvault secret user permissions to the Automation account
Write-Verbose "Adding automation account Keyvault Secret User."
New-AzRoleAssignment -ObjectId (Get-AzAutomationAccount -AutomationAccountName $autoMationAccountName -ResourceGroupName $resourceGroup).Identity.PrincipalId -RoleDefinitionName "Key Vault Secrets User" -Scope $kv.ResourceId
#Create SPN
Write-Verbose "Creating read SPN..."
try {
    $sp = New-AzADServicePrincipal -DisplayName $spnName -Role Reader
    $app= get-azadapplication -appId $sp.appId
    #Write-output "SPN Created: AppId: $($sp.ApplicationId) - Object Id: $($sp.Id) Secret: $($sp.PasswordCredentials.SecretText)"
    #adds guardrail read SPN
    Write-Verbose "Adding SPN secret to keyvault."
    $secretvalue = ConvertTo-SecureString $sp.PasswordCredentials.SecretText -AsPlainText -Force 
    $secret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "Guardrails-read" -SecretValue $secretvalue
}
catch { 
    Write-error "Error creating SPN (read)."
}
Write-Verbose "Adding workspacekey secret to keyvault."
$workspaceKey=(Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $resourcegroup -Name $logAnalyticsworkspaceName).PrimarySharedKey
$secretvalue = ConvertTo-SecureString $workspaceKey -AsPlainText -Force 
$secret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "WorkSpaceKey" -SecretValue $secretvalue
#endregion

#region Import main runbook
#create Runbooks specific for this deployment:
Write-Verbose "Importing Runbooks." #only one for now, as a template.
$parameterTemplate=get-content $("$mainRunbookpath\main_template.ps1")
$parameterTemplate=$parameterTemplate.Replace("%wsid%",$(Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourcegroup -Name $logAnalyticsworkspaceName).CustomerId)
$parameterTemplate=$parameterTemplate.Replace("%vaultName%",$keyVaultName)
$parameterTemplate=$parameterTemplate.Replace("%resourceGroup%",$resourceGroup)
$parameterTemplate=$parameterTemplate.Replace("%storageAccountName%",$storageaccountName)
$parameterTemplate=$parameterTemplate.Replace("%FirstBreakGlassUPN%",$FirstBreakGlassUPN)
$parameterTemplate=$parameterTemplate.Replace("%GuardrailReaderAppID%",$sp.appId)
$parameterTemplate | out-file "$mainRunbookpath\main.ps1" -Force
Import-AzAutomationRunbook -Name $mainRunbookName -Path "$mainRunbookpath\main.ps1" -Description $mainRunbookDescription -Type PowerShell -Published -ResourceGroupName $resourcegroup -AutomationAccountName $autoMationAccountName
#Create schedule
New-AzAutomationSchedule -ResourceGroupName $resourcegroup -AutomationAccountName $autoMationAccountName -Name "GR-Hourly" -StartTime (get-date).AddHours(1) -HourInterval 1
#Register
Register-AzAutomationScheduledRunbook -Name $mainRunbookName -ResourceGroupName $resourcegroup -AutomationAccountName $autoMationAccountName -ScheduleName "GR-Hourly"
# Remove-item '$mainRunbookpath\main.ps1'
#endregion

#region Other secrects
#Breakglass accounts and UPNs
$secretvalue = ConvertTo-SecureString $bga1 -AsPlainText -Force 
$secret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "BGA1" -SecretValue $secretvalue
$secretvalue = ConvertTo-SecureString $bga2 -AsPlainText -Force 
$secret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "BGA2" -SecretValue $secretvalue
$secretvalue = ConvertTo-SecureString $FirstBreakGlassUPN -AsPlainText -Force 
$secret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "FirstBreakGlassUPN" -SecretValue $secretvalue
$secretvalue = ConvertTo-SecureString $SecondBreakGlassUPN -AsPlainText -Force 
$secret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "SecondBreakGlassUPN" -SecretValue $secretvalue
#endregion

#region Assign permissions
# SPN requires: Organization.Read.All, User.Read, User.Read.All, UserAuthenticationMethod.Read.All, Policy.Read.All
try {
    Write-Verbose "Assigning read SPN the requires AD permissions."
    #
    $graph=(Get-AzADServicePrincipal -ApplicationId 00000003-0000-0000-c000-000000000000)
    $approleid=($graph.AppRole | where {$_.Value -eq "Organization.Read.All"}).Id
    Add-AzADAppPermission -ObjectId $App.Id -ApiId 00000003-0000-0000-c000-000000000000 -Type Role -PermissionId $approleid
    $approleid=($graph.AppRole | where {$_.Value -eq "User.Read.All"}).Id
    Add-AzADAppPermission -ObjectId $App.Id -ApiId 00000003-0000-0000-c000-000000000000 -Type Role -PermissionId $approleid
    $approleid=($graph.AppRole | where {$_.Value -eq "UserAuthenticationMethod.Read.All"}).Id
    Add-AzADAppPermission -ObjectId $App.Id -ApiId 00000003-0000-0000-c000-000000000000 -Type Role -PermissionId $approleid
    $approleid=($graph.AppRole | where {$_.Value -eq "Policy.Read.All"}).Id
    Add-AzADAppPermission -ObjectId $App.Id -ApiId 00000003-0000-0000-c000-000000000000 -Type Role -PermissionId $approleid
}
catch {
    Write-Error "Error adding SPN Permissions."
}
#endregion
Write-Output "Adding reader permissions to current subscription to the automation account. Add other permissions as required."
New-AzRoleAssignment -ObjectId (Get-AzAutomationAccount -ResourceGroupName $resourcegroup -Name $autoMationAccountName).Identity.PrincipalId -RoleDefinitionName Reader -Scope "/subscriptions/$((get-azcontext).Subscription.Id)"
Start-Sleep -Seconds 20
Write-Output "Setup complete. Please add the SPN permissions to the required subscriptions to allow ver complicance assessment."
Write-Output "Please visit https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredApps , click on the new SPN ($spnName), select API Permissions and click Grant admin consent."
Write-Output "Once permissions above are set, run the main runbook for initial data gathering:"
Write-output "Start-AzAutomationRunbook -Name ""main"" -AutomationAccountName $autoMationAccountName -ResourceGroupName $resourcegroup"

