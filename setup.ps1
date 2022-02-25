param (
        [Parameter(Mandatory=$true)]
        [string]
        $configFilePath,
        [Parameter(Mandatory=$false)]
        [string]
        $userId,
        [Parameter(Mandatory=$false)]
        [string]
        $existingKeyVaultName,
        [Parameter(Mandatory=$false)]
        [string]
        $existingKeyVaultRG,
        [Parameter(Mandatory=$false)]
        [string]
        $existingWorkspaceName,
        [Parameter(Mandatory=$false)]
        [string]
        $existingWorkSpaceRG,
        [Parameter(Mandatory=$false)]
        [switch]
        $skipDeployment
    )
#region Configuration and initialization
import-module .\blob-functions.psm1
# test
#Configuration Variables
$randomstoragechars=-join ((97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
$config=get-content $configFilePath | convertfrom-json

$keyVaultName=$config.keyVaultName
$resourcegroup=$config.resourcegroup
$region=$config.region
$storageaccountName="$($config.storageaccountName)$randomstoragechars"
$logAnalyticsworkspaceName=$config.logAnalyticsworkspaceName
$autoMationAccountName=$config.autoMationAccountName
$keyVaultRG=$resourcegroup #initially, same RG.
$logAnalyticsWorkspaceRG=$resourcegroup #initially, same RG.
$deployKV='true'
$deployLAW='true'
#$spnName=$config.spnName
$bga1=$config.bga1 #Break glass account 1
$bga2=$config.bga2 #Break glass account 2
$PBMMPolicyID=$config.PBMMPolicyID
#$FirstBreakGlassUPN=$config.FirstBreakGlassUPN 
#$SecondBreakGlassUPN=$config.SecondBreakGlassUPN

#Other Variables
$mainRunbookName="main"
$mainRunbookPath='.\'
$mainRunbookDescription="Guardrails Main Runbook"

#Tests if logged in:
$subs = Get-AzSubscription -ErrorAction SilentlyContinue
if(-not($subs))
{
    Connect-AzAccount
    $subs = Get-AzSubscription -ErrorAction SilentlyContinue
}
if ($subs.count -gt 1)
{
    Write-output "More than one subscription detected. Current subscription $((get-azcontext).Name)"
    Write-output "Please select subscription for deployment or Enter to keep current one:"
    $i=1
    $subs | ForEach-Object {Write-output "$i - $($_.Name) - $($_.SubscriptionId)";$i++}
    [int]$selection=Read-Host "Select Subscription number: (1 - $($i-1))"
}
if ($selection -ne 0)
{
    if ($selection -gt 0 -and $selection -le ($i-1))  { 
        Select-AzSubscription -SubscriptionObject $subs[$selection-1]
    }
    else {
        Write-output "Invalid selection. ($selection)"
        break
    }
}
else {
    Write-host "Keeping current subscription."
}
#region Let's deal with existing stuff...
# Keyvault first
if (!([string]::IsNullOrEmpty($existingKeyVaultName)))
{
    Write-Output "Will try to use an existing Keyvault."
    $keyVaultName=$existingKeyVaultName
    $keyVaultRG=$existingKeyVaultRG
    $deployKV='false'
}
#log analytics now...
if (!([string]::IsNullOrEmpty($existingWorkspaceName)))
{
    Write-Output "Will try to use an existing Log Analytics workspace."
    $logAnalyticsworkspaceName=$existingWorkspaceName
    $logAnalyticsWorkspaceRG=$existingWorkSpaceRG
    $deployLAW='false' #it will be passed to bicep.
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
#region keyvault verification
$kvContent=((Invoke-AzRest -Uri "https://management.azure.com/subscriptions/$((Get-AzContext).Subscription.Id)/providers/Microsoft.KeyVault/checkNameAvailability?api-version=2021-11-01-preview" `
-Method Post -Payload "{""name"": ""$keyVaultName"",""type"": ""Microsoft.KeyVault/vaults""}").Content | ConvertFrom-Json).NameAvailable
if (!($kvContent))
{
    write-output "Error: keyvault name $keyVaultName is not available."
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
if ($null -eq $currentUserId)
{
    Write-Error "Error: no current user could be found in current Tenant. Context: $((Get-AzAccessToken).UserId). Override specified: $userId."
    break;
}
#region  Template Deployment
$parameterTemplate=get-content .\parameters_template.json
$parameterTemplate=$parameterTemplate.Replace("%kvName%",$keyVaultName)
$parameterTemplate=$parameterTemplate.Replace("%location%",$region)
$parameterTemplate=$parameterTemplate.Replace("%storageAccountName%",$storageaccountName)
$parameterTemplate=$parameterTemplate.Replace("%logAnalyticsWorkspaceName%",$logAnalyticsworkspaceName)
$parameterTemplate=$parameterTemplate.Replace("%automationAccountName%",$autoMationAccountName)
$parameterTemplate=$parameterTemplate.Replace("%subscriptionId%",(Get-AzContext).Subscription.Id)
$parameterTemplate=$parameterTemplate.Replace("%PBMMPolicyID%",$PBMMPolicyID)
$parameterTemplate=$parameterTemplate.Replace("%deployKV%",$deployKV)
$parameterTemplate=$parameterTemplate.Replace("%deployLAW%",$deployLAW)
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
$kv=Get-AzKeyVault -ResourceGroupName $keyVaultRG -VaultName $keyVaultName
New-AzRoleAssignment -ObjectId $currentUserId -RoleDefinitionName "Key Vault Administrator" -Scope $kv.ResourceId
Write-Output "Sleeping 30 seconds to allow for permissions to be propagated."
Start-Sleep -Seconds 30
#region Secret Setup
# Adds keyvault secret user permissions to the Automation account
Write-Verbose "Adding automation account Keyvault Secret User."
New-AzRoleAssignment -ObjectId (Get-AzAutomationAccount -AutomationAccountName $autoMationAccountName -ResourceGroupName $resourceGroup).Identity.PrincipalId -RoleDefinitionName "Key Vault Secrets User" -Scope $kv.ResourceId

Write-Verbose "Adding workspacekey secret to keyvault."
$workspaceKey=(Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $logAnalyticsWorkspaceRG -Name $logAnalyticsworkspaceName).PrimarySharedKey
$secretvalue = ConvertTo-SecureString $workspaceKey -AsPlainText -Force 
$secret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "WorkSpaceKey" -SecretValue $secretvalue
#endregion

#region Import main runbook
Write-Verbose "Importing Runbooks." #only one for now, as a template.
Import-AzAutomationRunbook -Name $mainRunbookName -Path "$mainRunbookpath\main.ps1" -Description $mainRunbookDescription -Type PowerShell -Published -ResourceGroupName $resourcegroup -AutomationAccountName $autoMationAccountName
#Create schedule
New-AzAutomationSchedule -ResourceGroupName $resourcegroup -AutomationAccountName $autoMationAccountName -Name "GR-Hourly" -StartTime (get-date).AddHours(1) -HourInterval 1
#Register
Register-AzAutomationScheduledRunbook -Name $mainRunbookName -ResourceGroupName $resourcegroup -AutomationAccountName $autoMationAccountName -ScheduleName "GR-Hourly"
#endregion

#region Other secrects
#Breakglass accounts and UPNs
$secretvalue = ConvertTo-SecureString $bga1 -AsPlainText -Force 
$secret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "BGA1" -SecretValue $secretvalue
$secretvalue = ConvertTo-SecureString $bga2 -AsPlainText -Force 
$secret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "BGA2" -SecretValue $secretvalue
#endregion
#region Assign permissions
$GraphAppId="00000003-0000-0000-c000-000000000000"
Write-Output "Adding Permissions to Automation Account - Managed Identity"
import-module AzureAD.Standard.Preview
AzureAD.Standard.Preview\Connect-AzureAD -Identity -TenantID $env:ACC_TID
$MSI = (Get-AzureADServicePrincipal -Filter "displayName eq '$autoMationAccountName'")
#Start-Sleep -Seconds 10
$graph = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"
#$approleid = ($GraphServicePrincipal.AppRoles | `
#Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}).Id
$appRoleIds=@("Organization.Read.All", "User.Read.All", "UserAuthenticationMethod.Read.All","Policy.Read.All")
foreach ($approleidName in $appRoleIds)
{
    Write-Output "Adding permission to $approleidName"
    $approleid=($graph.AppRoles | Where-Object {$_.Value -eq $approleidName}).Id
    if ($null -ne $approleid)
    {
        try {
            New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId -ResourceId $graph.ObjectId -Id $approleid
        }
        catch {
            "Error assigning permissions $approleid to $approleidName"
        }
    }
    else {
        Write-Output "App Role Id $approleid Not found... :("
    }
}
#endregion
$rootmg=get-azmanagementgroup | ? {$_.Id.Split("/")[4] -eq (Get-AzContext).Tenant.Id}
$AAId=(Get-AzAutomationAccount -ResourceGroupName $resourcegroup -Name $autoMationAccountName).Identity.PrincipalId
Write-Output "Assigning reader access to the Automation Account Managed Identity for MG: $($rootmg.DisplayName)"
New-AzRoleAssignment -ObjectId $AAId -RoleDefinitionName Reader -Scope $rootmg.Id
#New-AzRoleAssignment -ObjectId $AAId -RoleDefinitionName "Storage Blob Data Reader" -Scope (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageaccountName).Id
New-AzRoleAssignment -ObjectId $AAId -RoleDefinitionName "Reader and Data Access" -Scope (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageaccountName).Id
<#
if ($subs.count -gt 1) # More than one subscriptions is available for the user installing the solution.
{   
    Write-output "More than one subscription detected. Current subscription $((get-azcontext).Name)"
    $selection=Read-Host "Would you like to assign reader permission for the solution to all available subcriptions (Y/N). Default is No."
}
if ($selection -eq 'Y')
{
    $AAId=(Get-AzAutomationAccount -ResourceGroupName $resourcegroup -Name $autoMationAccountName).Identity.PrincipalId
    foreach ($sub in $subs)
    {
        New-AzRoleAssignment -ObjectId $AAId -RoleDefinitionName Reader -Scope "/subscriptions/$(sub.Id)"        
    }   
}
else {
    Write-Output "Adding reader permissions to current subscription to the automation account. Add other permissions as required."
    New-AzRoleAssignment -ObjectId (Get-AzAutomationAccount -ResourceGroupName $resourcegroup -Name $autoMationAccountName).Identity.PrincipalId -RoleDefinitionName Reader -Scope "/subscriptions/$((get-azcontext).Subscription.Id)"
}
#>
#Start-Sleep -Seconds 20
#Write-Output "Setup complete. Please add the SPN permissions to the required subscriptions to allow ver complicance assessment."
#Write-Output "Please visit https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredApps , click on the new SPN ($spnName), select API Permissions and click Grant admin consent."
#Write-Output "Once permissions above are set, run the main runbook for initial data gathering:"
#Write-output "Start-AzAutomationRunbook -Name ""main"" -AutomationAccountName $autoMationAccountName -ResourceGroupName $resourcegroup"
Start-AzAutomationRunbook -Name "main" -AutomationAccountName $autoMationAccountName -ResourceGroupName $resourcegroup

