#Install-Module Az.Storage -Repository PSGallery -Force

Get-Content $(Join-Path -Path $(Split-Path $PSScriptRoot -Parent) -ChildPath ".env" ) | ForEach-Object {
    $name, $value = $_.split('=', 2)
    if ([string]::IsNullOrWhiteSpace($name) || $name.Contains('#')) {
        continue
    }
    Set-Content env:\$name $value
}

$TenantId = $env:TenantId
$ApplicationId = $env:ApplicationId
$AppSecret = $env:AppSecret

$Fabric = @{
    Workspace = 'FabricResearch'
    Lakehouse = 'MDW'
    Itemtype  = 'Lakehouse'
    Folder    = 'somesubfolder/ODXtest'
}

$SrcFile = 'SampleData/csv/testfile1.csv'


###############################################

$SecurePassword = ConvertTo-SecureString -String $AppSecret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationId, $SecurePassword

#Update-AzConfig -DefaultSubscriptionForLogin ''
Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential
$bearerToken = Get-AzAccessToken -ResourceTypeName Storage
#$bearerToken.Token | Set-Clipboard

$SrcFileName = Split-Path -Path $SrcFile -Leaf

$BlockRequestParams = @{
    Uri                  = "https://onelake.blob.fabric.microsoft.com/$($Fabric.Workspace)/$($Fabric.Lakehouse).$($Fabric.Itemtype)/Files/$($Fabric.Folder)/$($SrcFileName)?comp=block&blockid=" + [System.Web.HttpUtility]::UrlEncode([Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("1"))) 
    Method               = "PUT"
    Headers              = @{
        Authorization                   = "Bearer $($bearerToken.Token)"
        "x-ms-blob-type"                = "BlockBlob"
        "Date"                          = (Get-Date).ToUniversalTime().ToString('ddd, dd MMM yyyy HH:mm:ss') + " GMT" #"Sun, 06 Nov 1994 08:49:37 GMT"
        "x-ms-version"                  = "2023-08-03"
        "x-ms-blob-content-disposition" = 'attachment; filename="' + $SrcFileName + '"'  
    }
    SkipHeaderValidation = $true
    InFile               = $SrcFile
}

Invoke-WebRequest @BlockRequestParams


$BlockListBody = @'
<?xml version="1.0" encoding="utf-8"?>  
<BlockList>  
  <Latest>{0}</Latest>
</BlockList>  
'@ -f [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("1"))

$BlockListRequestParams = @{
    Uri                  = "https://onelake.blob.fabric.microsoft.com/$($Fabric.Workspace)/$($Fabric.Lakehouse).$($Fabric.Itemtype)/Files/$($Fabric.Folder)/$($SrcFileName)?comp=blocklist"
    Method               = "PUT"
    Headers              = @{
        Authorization  = "Bearer $($bearerToken.Token)"
        "Date"         = (Get-Date).ToUniversalTime().ToString('ddd, dd MMM yyyy HH:mm:ss') + " GMT" #"Sun, 06 Nov 1994 08:49:37 GMT"
        "x-ms-version" = "2023-08-03"
        "Content-Type" = "application/xml"
    }
    SkipHeaderValidation = $true
    Body                 = $BlockListBody
}

Invoke-WebRequest @BlockListRequestParams