#region Functions
function copy-toBlob  {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $FilePath,
        [Parameter(Mandatory=$true)]
        [string]
        $storageaccountName,
        [Parameter(Mandatory=$true)]
        [string]
        $resourcegroup,
        [Parameter(Mandatory=$false)]
        [switch]
        $force
    )
    $psModulesContainerName="psmodules"
    try {
        $saParams = @{
            ResourceGroupName = $resourcegroup
            Name = $storageaccountName
        }
        $scParams = @{
            Container = $psModulesContainerName
        }
        $bcParams = @{
            File = $FilePath
            Blob = ($FilePath | Split-Path -Leaf)
        }
        if ($force)
        {Get-AzStorageAccount @saParams | Get-AzStorageContainer @scParams | Set-AzStorageBlobContent @bcParams -Force}
        else {Get-AzStorageAccount @saParams | Get-AzStorageContainer @scParams | Set-AzStorageBlobContent @bcParams}
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}
function get-blobs  {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $storageaccountName,
        [Parameter(Mandatory=$true)]
        [string]
        $resourcegroup
    )
    $psModulesContainerName="psmodules"
    try {
        $saParams = @{
            ResourceGroupName = $resourcegroup
            Name = $storageaccountName
        }

        $scParams = @{
            Container = $psModulesContainerName
        }
        return (Get-AzStorageAccount @saParams | Get-AzStorageContainer @scParams | Get-AzStorageBlob)
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}
#endregion