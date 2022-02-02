Connect-AzAccount
Set-AzContext -Subscription "Azure CXP FTA Internal Subscription ISGOMAA"



$ResourceGroupName= "Guardrails"

$AutmationAccountame= "Guardrails"

$Uri = "https://guardrailsdeploymentst.blob.core.windows.net/modules/"
$GRSModules = @("Check-BreakGlassAccountProcedure.zip","Check-DeprecatedAccounts.zip","Check-ExternalAccounts.zip","Check-GuardRailsConditionalAccessPolicie.zip"," Check-MonitorAccount.zip","Detect-UserBGAUsersAuthMethods.zip","Get-AzureADLicenseType.zip","Validate-BreakGlassAccount.zip")


foreach($module in $GRSModules)
{
  $uri = $uri+$module
  $name= $($module.Split("."))[0]

  Set-AzAutomationModule -Name $name  -ContentLinkUri $Uri -AutomationAccountName $AutmationAccountame -ResourceGroupName $ResourceGroupName -ContentLinkVersion "0.1" -Verbose
}
