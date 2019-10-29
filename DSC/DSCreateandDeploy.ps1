$StorageResourceGroupName = 'common-rersource-files-rg'
$storageAccountName = 'commonstoragewrwh'
$ConfigurationPathFile = '.\webserver-dsc.ps1'

$parameters = @{
'configurationpath' = $ConfigurationPathFile
'resourcegroupname' = $StorageResourceGroupName
'StorageAccountName' = $storageAccountName
}

Publish-AzVMDscConfiguration @parameters -force -verbose

$VMNames = @("app1-vm-1-dev","app1-vm-2-dev")
$VMResourceGroupName = "app1-rg-dev"
$StorageResourceGroupName = 'common-rersource-files-rg'
$storageAccountName = 'commonstoragewrwh'
$DSCConfigurationName = 'webserver'
$DSCBlobName = 'DSC-WebBasic-v1.ps1.zip'

foreach ($vm in $VMNames)
{
    $parameters = @{
    'Version' = '2.76'
    'resourcegroupname' = $VMResourceGroupName
    'VMName' = $VM
    'ArchiveStorageAccountName' = $storageName
    'ArchiveResourceGroupName' = $StorageResourceGroupName
    'ArchiveBlobName' = $DSCBlobName
    'AutoUpdate' = $false
    'ConfigurationName' = $DSCConfigurationName
    }

    Set-AzVMDscExtension @parameters -verbose 
}
