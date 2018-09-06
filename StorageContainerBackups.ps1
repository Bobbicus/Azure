<#
    .SYNOPSIS
    Azure script  - takes a copy of any storage accounts tagged with backup:true
       
    .DESCRIPTION
    Checks which storage accounts have tag of backup:true, checks if there is a corresponding folder with bup suffix, if not present it creates it
    the script then makes a new container in the backup storage account it appends the date/time and tehn copys all blobs from the original container
    keywords: blob,storage,container
    Prerequisites: Yes Original Storage Account must be in place and backup tag set to true
    Makes changes: Yes
    Changes Made:
        Creates new backup storgae account if needed
        Copys blobs from source container to backup container


    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 4.0
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin :: 10-AUG-2017 :: N/A      :: Joe Bloggs  :: Release
#>

#Add-AzureRmAccount

#Get all storage accounts
$StorageAccs = Get-AzureRmStorageAccount | select StorageAccountName,ResourceGRoupName,Tags,Location

#Loop through storage accounts and check which ones have backup tag set to true
$StorCollection = @()
foreach ($stor in $StorageAccs)
{

    if ($stor.Tags.Keys -eq "backup" -and $stor.Tags.Values -eq "true")
    {
        $item = New-Object PSObject
        $item | Add-member -MemberType NoteProperty -Name "StorageAccountName" -Value $stor.StorageAccountName
        $item | Add-member -MemberType NoteProperty -Name "ResourceGroupName" -Value $stor.ResourceGroupName
        $item | Add-member -MemberType NoteProperty -Name "BackupTag" -Value $stor.Tags.Values
        $item | Add-member -MemberType NoteProperty -Name "Location" -Value $stor.Location
        $StorCollection +=$item
    }
}

#from the list of storage accounts that have backup tag of true check if there is a corresponding backup bup storage accounts
$StorageAccsName = Get-AzureRmStorageAccount | select StorageAccountName  | Out-String 


function New-ContainerBackup
{
        foreach ($store in $StorCollection)
        {
            
                  #write-host $store.StorageAccountName
                  $StorageBup = $store.StorageAccountName+"bup"
     
                  #Get the source storage account key 
                  $srckey1 = (Get-AzureRmStorageAccountKey -ResourceGroupName $store.ResourceGroupName -name $store.StorageAccountName)[0].value
                  #set the source storage context 
                  $srccontext = New-AzureStorageContext -StorageAccountName $store.StorageAccountName -StorageAccountKey $srckey1

                  #Get the destination storage account key 
                  $destkey1 = (Get-AzureRmStorageAccountKey -ResourceGroupName $store.ResourceGroupName -name $StorageBup)[0].value
                  #set the destination storage context 
                  $destcontext = New-AzureStorageContext -StorageAccountName $StorageBup -StorageAccountKey $destkey1

                  #Get all the containers in current storage account
                  $containers = Get-AzureStorageContainer -Context $srccontext
          
          
                  foreach ($cont in $containers)
                  {

                    $SourceStorageContainer = $cont.Name
            
            
                    write-host $SourceStorageContainer      -ForegroundColor Cyan
                    #Get the date and remove the . from the string
                    $date = get-date -format yyyy.MM.dd.hh.mm
                    $datetrimmed = $date -replace '\.', '' 

                    $DestStorageContainer = $SourceStorageContainer+$datetrimmed
                    New-AzureStorageContainer -Name $DestStorageContainer -Context $destcontext

                    $Blobs = Get-AzureStorageBlob -Context $srccontext -Container $cont.Name
            
                        foreach ($Blob in $Blobs)
                        {
                        ### Start the asynchronous copy - specify the source authentication with -SrcContext ### 
                        $blob1 = Start-AzureStorageBlobCopy -SrcContext $srcContext -SrcContainer $SourceStorageContainer -SrcBlob $Blob.Name -DestContext $destcontext -DestContainer $DestStorageContainer -DestBlob $Blob.Name     
                        }
                    }
         
                     <#
                    write-host "destination container details" -ForegroundColor Green
                    $containersdest = Get-AzureStorageContainer -Context $destcontext
                    $containersdest 
                    #>
              }
        
}

function Set-StorageAccount
{

    foreach ($store in $StorCollection)
    {
        #write-host $store.StorageAccountName
        $StorageBup = $store.StorageAccountName+"bup"
        if ($StorageAccsName.Contains($StorageBup))
        {
              write-host $store.StorageAccountName "Container Exists Moving onto copy operation"
              #New-ContainerBackup

          }
            if (!$StorageAccsName.Contains($StorageBup))
            {
                      #If no backup storage account exists create a new one with name and bup suffix
                      write-host "no backup storage account for"  $Store.StorageAccountName
                      $OriginalSA = $Store.StorageAccountName
                      write-host "Creating new backup storage account"  $StorageBup 
                      #create a new storage account with SKU Standard_LRS and a tag of retention, the number can be changed to match the required retention
                      #these tags are used in other scripts to clean-up old bakcup containers
                      New-AzureRmStorageAccount -ResourceGroupName $store.ResourceGroupName -Name $StorageBup -Location $Store.Location -SkuName "Standard_LRS" -Tag @{"retention"= "7";"backedupfrom"= $OriginalSA}
                      #New-ContainerBackup

            }
    
    }
}


Set-StorageAccount

New-ContainerBackup