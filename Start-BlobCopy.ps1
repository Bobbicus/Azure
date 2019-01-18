<#
    .SYNOPSIS
    Azure script  - takes a copy of a blob and moves to another storage account
       
    .DESCRIPTION
    User picks the source and destination storage account and picks the blob to copy. This is then copied to the destination account. 
    Prerequisites: Yes Source and desitination account must exist.
    Makes changes: Yes
    Changes Made:
        Copys blobs from source container to destiantion container


    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 4.0
    Version Table:
    Version :: Author             :: Live Date   :: 
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 18-Jan-2019 :: 
#>

#Add-AzureRmAccount

#Get all storage accounts
$StorageAccs = Get-AzureRmStorageAccount | select StorageAccountName,ResourceGRoupName,Tags,Location
write-host "Select source storage account" -ForegroundColor Cyan 
$SourceAccount = $StorageAccs | Out-GridView -OutputMode Single
write-host "`nSelect destination storage account" -ForegroundColor Cyan 
$DestinationAccount  = $StorageAccs | Out-GridView -OutputMode Single

#Get the source storage account key 
$srckey = (Get-AzureRmStorageAccountKey -ResourceGroupName $SourceAccount.ResourceGroupName -name $SourceAccount.StorageAccountName)[0].value
      
#set the source storage context 
$srccontext = New-AzureStorageContext -StorageAccountName $SourceAccount.StorageAccountName -StorageAccountKey $srckey

#Get the destination storage account key 
$destkey = (Get-AzureRmStorageAccountKey -ResourceGroupName $DestinationAccount.ResourceGroupName -name $DestinationAccount.StorageAccountName)[0].value
#set the destination storage context 
$destcontext = New-AzureStorageContext -StorageAccountName  $DestinationAccount.StorageAccountName -StorageAccountKey $destkey

#Get all the containers in current storage account
$srccontainers = Get-AzureStorageContainer -Context $srccontext
write-host "`nSelect source container" -ForegroundColor Cyan     
$SourceConatiner = $srccontainers | Out-GridView -OutputMode Single

$SourceStorageContainerName = $SourceConatiner.Name
            
write-host $SourceStorageContainerName     -ForegroundColor Cyan

$destcontainers = Get-AzureStorageContainer -Context $destcontext
#check if conatiner exists in destination folder and create a new container matching the source container if needed.
if (!$destcontainers)
{
    write-host "no containers exist"
    New-AzureStorageContainer -Name $SourceStorageContainerName  -Context $destcontext
}
elseif ($destcontainers.name -contains $SourceStorageContainerName)
{
    write-host "container $SourceStorageContainerName exists in destination folder"
}
elseif ($destcontainers.name -notcontains $SourceStorageContainerName)
{
    write-host "no matching containers exist, creating new container named $SourceStorageContainerName"
    New-AzureStorageContainer -Name $SourceStorageContainerName -Context $destcontext
}

$destcontainers = Get-AzureStorageContainer -Context $destcontext
write-host "`nSelect destination container" -ForegroundColor Cyan         
$DestiantionConatiner = $destcontainers | Out-GridView -OutputMode Single

#list blobs from source folder.
$SrcBlobs = Get-AzureStorageBlob -Context $srccontext -Container $SourceStorageContainerName
write-host "`nSelect source blob to copy" -ForegroundColor Cyan 
#Select source blob to copy
$SourceBlob = $SrcBlobs| Out-GridView -OutputMode Single   


#list blobs from destination folder.
$destBlobs = Get-AzureStorageBlob -Context $destcontext -Container $SourceStorageContainerName

#Check if blob exists in destiantion folder before proceeding
$srcblobname = $SourceBlob.Name
#check if conatiner exists in destination folder and create a new container matching the source container if needed.
if (!$destBlobs)
{
   write-host "no blobs exists proceeding with copy"
   Start-AzureStorageBlobCopy -SrcContext $srcContext -SrcContainer $SourceStorageContainerName -SrcBlob $SourceBlob.Name -DestContext $destcontext -DestContainer $DestiantionConatiner.name  -DestBlob $SourceBlob.Name 
}
elseif ($destBlobs.name -contains $SourceBlob.Name)
{
    write-host "`nWARNING: blob with name '$srcblobname'exists proceeding" -ForegroundColor Red
    $UserInput = read-host "do you want to overwite the blob file '$srcblobname' (y/n)"
    while("y","n" -notcontains $UserInput)
    {
	    $UserInput = Read-Host "do you want to overwite the blob file '$srcblobname' (y/n)"
    }
    If ($UserInput -eq "y")
    {
        write-host "Overewriting exising file" -ForegroundColor Yellow
        Start-AzureStorageBlobCopy -SrcContext $srcContext -SrcContainer $SourceStorageContainerName -SrcBlob $SourceBlob.Name -DestContext $destcontext -DestContainer $DestiantionConatiner.name  -DestBlob $SourceBlob.Name -force
    }
    elseif ($UserInput -eq "n")
    {
        Write-Host "`nBlob not overwritten exiting script"
    }
}
