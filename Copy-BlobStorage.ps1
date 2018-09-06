Add-AzureRmAccount

Set-AzureRmContext -Subscription e12342b2-e1234-46d0-800f-5635462a5768918

$StorageAccs = Get-AzureRmStorageAccount -ResourceGroupName bobtest123 -Name bobtest123 | select StorageAccountName,ResourceGRoupName,Tags,Location


$srckey1 = (Get-AzureRmStorageAccountKey -ResourceGroupName $StorageAccs.ResourceGroupName -name $StorageAccs.StorageAccountName)[0].value

#set the source storage context 
$srccontext = New-AzureStorageContext -StorageAccountName $StorageAccs.StorageAccountName -StorageAccountKey $srckey1

$containers = Get-AzureStorageContainer -Context $srccontext

 $Blobs = Get-AzureStorageBlob -Context $srccontext -Container $cont.Name
            
foreach ($Blob in $Blobs)
{
### Start the asynchronous copy - specify the source authentication with -SrcContext ### 
$blob1 = Start-AzureStorageBlobCopy -SrcContext $srcContext -SrcContainer $SourceStorageContainer -SrcBlob $Blob.Name -DestContext $destcontext -DestContainer $DestStorageContainer -DestBlob $Blob.Name     
}