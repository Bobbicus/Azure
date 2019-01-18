<#
    .SYNOPSIS
    Check state of azure storage blob lease and unlock if required.
       
    .DESCRIPTION
    Check state of blob lease and unlock if required.

    Makes changes: Yes
    Changes Made:
    Release lease on blob

    .EXAMPLE
    Full command: 
    Description: <description of what the command does>
    Output: <List output>
       
    .OUTPUTS
    <List outputs>
        
    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 4
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 28/11/2018  :: N/A      ::  :: Release
#>
 
#Get all storage accounts
$StorageAccAll = Get-AzureRmStorageAccount | select StorageAccountName,ResourceGRoupName,Tags,Location 
#User input to select the container to work with.
$StorageAcc = $StorageAccAll | Out-GridView -OutputMode Single

#Uncomment below if you want to hard code the storage container.
#$StorageAcc = Get-AzureRmStorageAccount | select StorageAccountName,ResourceGRoupName,Tags,Location | Where-Object {$_.StorageAccountName -eq %storageAcc_name%}

#Get the source storage account key 
$srckey1 = (Get-AzureRmStorageAccountKey -ResourceGroupName $StorageAcc.ResourceGroupName -name $StorageAcc.StorageAccountName)[0].value
#set the source storage context 
$srccontext = New-AzureStorageContext -StorageAccountName $StorageAcc.StorageAccountName -StorageAccountKey $srckey1

              
#Get all the containers in current storage account
$containers = Get-AzureStorageContainer -Context $srccontext
                    
        
$tfstatefile = foreach ($cont in $containers)
{
    Get-AzureStorageBlob -Container $cont.Name -Context $srccontext
}
#Get the state files and provide menu for user to select blob to work with
$tffileToUnlock = $tfstatefile | Out-GridView -OutputMode Single
$tfstatefilename = $tffileToUnlock.Name
#Get the lease state of the blob
$leaseStatus = $tffileToUnlock.ICloudBlob.Properties.LeaseStatus 

#Check the lease state of the selected blob, if it is locked confirm whether user wants to break the lease.
If($leaseStatus -eq "Locked") 
{ 
    $UserInput = read-host "do you want to unlock lease on '$tfstatefilename' blob (y/n)"
    while("y","n" -notcontains $UserInput)
    {
	    $UserInput = Read-Host "do you want to unlock(y/n)"
    }
    If ($UserInput -eq "y")
    {
        $tffileToUnlock.ICloudBlob.BreakLease() 
        Write-Host "Successfully broken lease on '$tfstatefilename' blob." 
    }
    elseif ($UserInput -eq "n")
    {
        Write-Host "Blob leases state not changed"
    }
 
} 
else
{ 
    Write-Host "The '$tfstatefilename' blob's lease status is unlocked." 
} 