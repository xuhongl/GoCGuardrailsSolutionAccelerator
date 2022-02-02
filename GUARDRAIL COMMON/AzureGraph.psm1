class Authentication 
{
    [string]$ressource = "https://graph.microsoft.com/";
    [string]$SPNID;
    [string]$SPNSecret;
    [string]$TenantName ;
   

    Authentication(){}
    Authentication([string] $SPNID, [string]$SPNSecret, [string]$TenantName)
    {
      $this.SPNID= $SPNID; 
      $this.SPNSecret=$SPNSecret;
      $this.TenantName= $TenantName;
    }

     [PSObject] GraphConnect ([string]$SPNID,[string] $SPNSecret,[string] $TenantName)
       {

        $ReqTokenBody = @{
            Grant_Type    = "client_credentials"
            Scope         = $this.ressource+".default"
            client_Id     = $SPNID
            Client_Secret = $SPNSecret
        }

      $TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token" -Method POST -Body $ReqTokenBody
           
      $obj = new-object psobject -Property @{'access_token'=$TokenResponse.access_token}
      return $obj
       }
 
  [void] setressource ([string] $ressource){
      $this.ressource=$ressource;
  }

}

