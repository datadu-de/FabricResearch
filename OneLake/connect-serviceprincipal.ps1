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
    Workspace = 'FabricResearch'.ToLower()
    Lakehouse = 'MDW'
    Itemtype  = 'Lakehouse'
    Folder    = 'somesubfolder/ODXtest'
}

$SrcFile = 'SampleData/csv/testfile3.csv'


###############################################

$SecurePassword = ConvertTo-SecureString -String $AppSecret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationId, $SecurePassword

Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential

$ctx = New-AzStorageContext `
    -StorageAccountName 'onelake' `
    -UseConnectedAccount `
    -endpoint 'fabric.microsoft.com' 


$DestFile = "$($Fabric.Lakehouse).$($Fabric.Itemtype)/Files/$($Fabric.Folder)/$($SrcFileName)"

$SrcFileName = Split-Path $SrcFile -leaf

New-AzDataLakeGen2Item -Context $ctx -FileSystem $($Fabric.Workspace.ToLower()) -Path $DestFile -Source $SrcFile -Force
