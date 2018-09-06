#References: 
#https://docs.microsoft.com/en-us/azure/backup/backup-azure-vms-automation
#https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-create-nsg-arm-ps 
#https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-nsg-arm-ps
#https://docs.microsoft.com/en-us/azure/virtual-machines/windows/change-availability-set
Login-AzureRmAccount
#Lets declare some variables. Keep in mind that the below is just an example and may need tweaking to meet the exact requirements of your deployment. This assumes you already have vm back ups happening.
Set-AzureRmContext -Subscription '685bd637-df24-4995-8cc3-0bd272f46b1d'
$subscriptionid = '685bd637-df24-4995-8cc3-0bd272f46b1d'
$rg = 'WEU-OXFAM-RSG-DED-PEOPLESOFT-HR-DEV'
$vmname = 'GBCLDHRDEVWEB3'
$vmresname = 'GBCLDHRDEVWEB3'
$vaultname = 'WEU-RSV-NONPCI-GRS'
$storagename = 'gbcldhrdevweb3restore'
$vnetname = 'WEU-VNET01'
$vnetrsg = 'WEU-OXFAM-RSG-SHR-MAN-DR'
$nsgname = 'WEU-VNET01-PEOPLESOFT-HR-DEV-DMZ-OGB-NSG'
$nsgrsg = 'WEU-OXFAM-RSG-SHR-MAN-DR'
$location = "West Europe"

$oldVM = get-azurermvm -ResourceGroupName $rg -Name $vmname

#Set Context:
Get-AzureRmRecoveryServicesVault -Name $vaultname | Set-AzureRmRecoveryServicesVaultContext

#Get Current Jobs:
Get-AzureRmRecoveryservicesBackupJob –Status "InProgress"

#Once that is done we check for and set a variable for the container of the VM in question:
$container = Get-AzureRmRecoveryServicesBackupContainer  -ContainerType "AzureVM" –Status "Registered" -FriendlyName $vmname

#Next we pull the backup item detals for that VM:
$item = Get-AzureRmRecoveryServicesBackupItem -Container $container -WorkloadType "AzureVM"

#After that we want to pull a list of the back up points:
$rp = Get-AzureRmRecoveryServicesBackupRecoveryPoint -Item $item

#At this point $rp[0] would hold the most recent restore point. Go ahead and kick off the restore job, saving it in a variable, be sure to set your storage account resource group name and storage account name for destination:
$restorejob = Restore-AzureRmRecoveryServicesBackupItem -RecoveryPoint $rp[13] -StorageAccountName $storagename -StorageAccountResourceGroupName $rg

#We need to wait for the restore to finish before proceeding:
Wait-AzureRmRecoveryServicesBackupJob -Job $restorejob -Timeout 43200

#After thats done you want the details for the disks:
$restorejob = Get-AzureRmRecoveryServicesBackupJob -Job $restorejob
$details = Get-AzureRmRecoveryServicesBackupJobDetails -Job $restorejob

#--------------------------------------------------------------------------------

#Get the container storage details and store them:
$properties = $details.properties
$storageAccountName = $properties["Target Storage Account Name"]
$containerName = $properties["Config Blob Container Name"]
$blobName = $properties["Config Blob Name"]

#Set the Azure storage context and restore the JSON configuration file:
Set-AzureRmCurrentStorageAccount -Name $storageaccountname -ResourceGroupName $rg
$destination_path = "C:\rs-pkgs\vmconfig.json"
Get-AzureStorageBlobContent -Container $containerName -Blob $blobName -Destination $destination_path
$obj = ((Get-Content -Path $destination_path -Raw -Encoding Unicode)).TrimEnd([char]0x00) | ConvertFrom-Json

#Using the JSON as well as details from the old VM lets create our base new restore VM:
$newVM = New-AzureRmVMConfig -VMSize $obj.'properties.hardwareProfile'.vmSize -VMName $vmresname -AvailabilitySetId $oldVM.AvailabilitySetReference.Id

#Lets create a new managed disk from our backup restore and attach it to our new server:
$storageType = "StandardLRS"
$osdiskname = $vmresname + "-OS"
$osVhdUri = $obj.'properties.storageProfile'.osDisk.vhd.uri
$diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Import -SourceUri $osVhdUri
$osDisk = New-AzureRmDisk -DiskName $osDiskName -Disk $diskConfig -ResourceGroupName $rg 
Set-AzureRmVMOSDisk -VM $newVM -ManagedDiskId $osDisk.Id -CreateOption "Attach" -Windows

#If you have any data disks you'll need something like the below (You can always attach these later, in the portal but the below does let you rename them)
foreach($dd in $obj.'properties.storageProfile'.dataDisks)
{
 $dataDiskName = $vmresname + "-data1";
 $dataVhdUri = $dd.vhd.uri ;
 $dataDiskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Import -SourceUri $dataVhdUri ;
 $dataDisk2 = New-AzureRmDisk -DiskName $dataDiskName -Disk $dataDiskConfig -ResourceGroupName $rg ;
 Add-AzureRmVMDataDisk -VM $newVM -Name $dataDiskName -ManagedDiskId $dataDisk2.Id -Lun $dd.Lun -CreateOption "Attach"
}

#Now we create a quick network profile, you'd have to loop to create multiple here, or you can just attach them in the portal later, the NSG pieces can be omitted or added later from the portal as well:
$nicName= 'GBCLDHRDEVWEB3-nic'
$nicrsg = 'WEU-OXFAM-RSG-DED-PEOPLESOFT-HR-DEV'
#$pip = New-AzureRmPublicIpAddress -Name $nicName -ResourceGroupName $rg -Location $location -AllocationMethod Dynamic
$vnet = Get-AzureRmVirtualNetwork -Name $vnetname -ResourceGroupName $vnetrsg
$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $nsgrsg -Name $nsgname
$nic = Get-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $nicrsg 
$newVM=Add-AzureRmVMNetworkInterface -VM $newVM -Id $nic.Id

#Now, let's create our new server:
New-AzureRmVM -ResourceGroupName $rg -Location $location -VM $newVM

#Be sure to double check any other configurations you might need ont he box such as backups, analyitics agents, extensions etc. 
Get-AzureRmVM | Where-Object {$_.Name -eq "GBCLDHRDEVWEB3"} | fl
