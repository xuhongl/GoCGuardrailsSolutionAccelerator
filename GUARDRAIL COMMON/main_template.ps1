#region import-module  
Using module AzureGraph

#endregion import-module 
Disable-AzContextAutosave

#region Parameters 
$GuardrailReaderAppID = "%GuardrailReaderAppID%" 
$StorageAzzountName = "%storageAccountName%"
$ContainerName = "guardrailsolutionaccelerator"
$ResourceGroupName = "%resourceGroup%"

$CtrName1 = "GUARDRAIL 1: PROTECT ROOT / GLOBAL ADMINS ACCOUNT"
$CtrName2 = "GUARDRAIL 2: MANAGEMENT OF ADMINISTRATIVE PRIVILEGES"
$CtrName4 = "GUARDRAIL 4: ENTERPRISE MONITORING ACCOUNTS"
$controlName8="GUARDRAIL 8: NETWORK SEGMENTATION AND SEPARATION"
$controlName9="GUARDRAIL 9: NETWORK SECUIRTY SERVICES"

[String] $LogType = "GuardrailsCompliance"
[String] $WorkSpaceID = "%wsid%"
[String] $KeyVaultName= "%vaultName%"
[String] $GuardrailReaderAppSecretName = "Guardrails-Read"
[String] $GuardrailWorkspaceIDKeyName = "WorkSpaceKey"
#endregion Parameters 

Connect-AzAccount -Identity 
$SubID = (Get-AzContext).Subscription.Id
$tenantID = (Get-AzContext).Tenant.Id
[String] $GuardrailReaderAppSecret  = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $GuardrailReaderAppSecretName -AsPlainText 
[String] $WorkspaceKey = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $GuardrailWorkspaceIDKeyName -AsPlainText 
#Write-output "Read secret: $GuardrailReaderAppSecret"
#Write-output "WS Id: $WorkSpaceID"
#Write-output "WS Key: $WorkspaceKey"

$BGA1=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name BGA1 -AsPlainText 
$BGA1=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name BGA2 -AsPlainText 
$FirstBreakGlassUPN=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name FirstBreakGlassUPN -AsPlainText 
$SecondBreakGlassUPN=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name SecondBreakGlassUPN -AsPlainText 

$auth = [Authentication]::new($GuardrailReaderAppID, $GuardrailReaderAppSecret, $tenantID)

$token = $auth.GraphConnect($GuardrailReaderAppID, $GuardrailReaderAppSecret, $tenantID)

Check-ProcedureDocument -StorageAccountName $StorageAzzountName -ContainerName $ContainerName `
    -ResourceGroupName $ResourceGroupName -ServicePrincipalName $GuardrailReaderAppID `
    -ServicePrincipalSecret $GuardrailReaderAppSecret -TenantID $tenantID -SubscriptionID $SubID `
    -DocumentName "BreakGlassAccountProcedure.txt" -ControlName $CtrName1 -ItemName "Break Glass account Procedure" `
    -LogType $LogType -WorkSpaceID  $WorkSpaceID -WorkspaceKey $WorkspaceKey

Get-BreakGlassAccounts -token $token.access_token  -ControlName $CtrName1 -ItemName "Break Glass account Creation" `
    -FirstBreakGlassUPN $FirstBreakGlassUPN -SecondBreakGlassUPN $SecondBreakGlassUPN `
    -LogType $LogType -WorkSpaceID  $WorkSpaceID -WorkspaceKey $WorkspaceKey
                    

Get-ADLicenseType -Token $token.access_token -ControlName $CtrName1 -ItemName "AD License Type" `
    -LogType $LogType -WorkSpaceID $WorkSpaceID -WorkspaceKey $WorkspaceKey 


Get-UserAuthenticationMethod -token $token.access_token -ControlName $CtrName1 -ItemName "MFA Enforcement" `
    -FirstBreakGlassEmail   $BGA1 `
    -SecondBreakGlassEmail  $BGA2 `
    -LogType $LogType -WorkSpaceID $WorkSpaceID -WorkspaceKey $WorkspaceKey 

Get-BreakGlassAccountLicense -token $token.access_token -ControlName $CtrName1 -ItemName "Microsoft 365 E5 Assignment" `
    -FirstBreakGlassUPN  $BGA1 `
    -SecondBreakGlassUPN  $BGA2 `
    -LogType $LogType -WorkSpaceID $WorkSpaceID -WorkspaceKey $WorkspaceKey 

Check-ProcedureDocument -StorageAccountName $StorageAzzountName -ContainerName $ContainerName `
    -ResourceGroupName $ResourceGroupName -ServicePrincipalName $GuardrailReaderAppID `
    -ServicePrincipalSecret $GuardrailReaderAppSecret -TenantID $tenantID -SubscriptionID $SubID `
    -DocumentName "ConfirmBreakGlassAccountResponsibleIsNotTechnical.txt" -ControlName $CtrName1 -ItemName "Responsibility of break glass accounts must be with someone not-technical, director level or above" `
    -LogType $LogType -WorkSpaceID  $WorkSpaceID -WorkspaceKey $WorkspaceKey


Get-BreakGlassOwnerinformation  -token $token.access_token -ControlName $CtrName1 -ItemName "Break Glass Account Owners Contact information" `
    -FirstBreakGlassUPNOwner $BGA1 `
    -SecondBreakGlassUPNOwner $BGA2 `
    -LogType $LogType -WorkSpaceID $WorkSpaceID -WorkspaceKey $WorkspaceKey 

Check-Policy -Token    $token.access_token   -AADPrivRolesPolicyName "ABCPrivateRole" -AzureMFAPolicyName "ABCPrivateRole" 


Check-ADDeletedUsers -Token $token.access_token -ControlName $CtrName2 -ItemName "Remove deprecated accounts" `
    -LogType $LogType -WorkSpaceID $WorkSpaceID -WorkspaceKey $WorkspaceKey

    
Check-ExternalUsers -Token $token.access_token -ControlName $CtrName2 -ItemName "Remove External accounts" `
    -LogType $LogType -WorkSpaceID $WorkSpaceID -WorkspaceKey $WorkspaceKey


Check-MonitorAccountCreation -Token $token.access_token -DepartmentNumner "56" -ControlName $CtrName4 -ItemName "Monitor Account Creation" `
    -LogType $LogType -WorkSpaceID $WorkSpaceID -WorkspaceKey $WorkspaceKey

#Guardrail module 8 
Get-SubnetComplianceInformation -ControlName $controlName8 -WorkSpaceID $WorkSpaceID -workspaceKey $WorkspaceKey

#Guardrail module 9
Get-VnetComplianceInformation -ControlName $controlName9 -WorkSpaceID $WorkSpaceID -workspaceKey $WorkspaceKey 

#Confirm-CloudConsoleAccess -token $token.access_token -PolicyName 
#Verify-DataLocationPolicy -ServicePrincipalName $GuardrailReaderAppID -ServicePrincipalSecret $GuardrailReaderAppSecret -TenantID $tenantID -SubscriptionID $SubID 
