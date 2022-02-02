class GRSCredentials 
{
  [string] $KeyVaultName;
  
  GRSCredential(){}
  GRSCredential([string] $KeyVaultName)
  {
     
     $this.$KeyVaultName= $KeyVaultName;
  }
   
  [string] Get-ServicePrincipalNameIDKey ([$string] $VaultName, [$string] $KeyName){
    try{
    Connect-AzAccount -Identity 
    }
    catch 
    $secret = Get-AzKeyVaultSecret -VaultName $KeyName -Name $KeyName 
    $ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue) 
    return "X"
  }

 
}




