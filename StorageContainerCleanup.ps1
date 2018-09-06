<#
    .SYNOPSIS
    Azure Script - Check containers with retention period of 7 days and removes old containers
       
    .DESCRIPTION
    Checks which storage accounts have tag of renention:7 and removes containers older than 7 days
    keywords: containers,retention,cleanup
    Prerequisites: Backup containers must exisit with retention period set to 7
    Makes changes: Yes
    Changes Made:
    Removes Containers older than 7days if retention tag is set
    Example use: <example command>
    Default: None
    .EXAMPLE
    Full command: <example command>
    Description: <description of what the command does>
    Output: <List output>
       
    .OUTPUTS
    <List outputs>
        
    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 4.0
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Robert Larkin :: 10-AUG-2017 :: N/A ::   :: Release
#>

#Add-AzureRmAccount

#Get all storage accounts
$StorageAccs = Get-AzureRmStorageAccount | select StorageAccountName,ResourceGRoupName,Tags,Location

#Loop through storage accounts and check which ones have backup tag set to true
$StorCollection = @()
foreach ($stor in $StorageAccs)
{

    if ($stor.Tags.Keys -eq "retention" -and $stor.Tags.Values -eq "7" -and $stor.StorageAccountName -like "*bup*")
    {
        $item = New-Object PSObject
        $item | Add-member -MemberType NoteProperty -Name "StorageAccountName" -Value $stor.StorageAccountName
        $item | Add-member -MemberType NoteProperty -Name "ResourceGroupName" -Value $stor.ResourceGroupName
        $item | Add-member -MemberType NoteProperty -Name "BackupTag" -Value $stor.Tags.Values
        $item | Add-member -MemberType NoteProperty -Name "Location" -Value $stor.Location
        $StorCollection +=$item
    }
}


foreach ($store in $StorCollection)
{  
            #Get the source storage account key 
            $srckey1 = (Get-AzureRmStorageAccountKey -ResourceGroupName $store.ResourceGroupName -name $store.StorageAccountName)[0].value
            #set the source storage context 
            $srccontext = New-AzureStorageContext -StorageAccountName $store.StorageAccountName -StorageAccountKey $srckey1

            #Get all the containers in current storage account
            $containers = Get-AzureStorageContainer -Context $srccontext
                  
            foreach ($cont in $containers)
            {

            $SourceStorageContainer = $cont.Name
                   
            #write-host $SourceStorageContainer  -ForegroundColor Cyan
            $RetentionDate = [DateTime]::UtcNow.AddDays(-7)
            $StorageContainer = Get-AzureStorageContainer -Container $SourceStorageContainer -Context $srccontext | Where-Object {$_.LastModified.UtcDateTime -lt $RetentionDate} 
              
            $StorageContainertoDelete = $StorageContainer.Name
                foreach ($OldCont in $StorageContainer)
                {

                    Write-host "will delete folder" $OldCont.Name -ForegroundColor DarkCyan
                    #Remove-AzureStorageContainer -Container $OldCont.Name -Context $srccontext -Force
                }

            }
}
        


        
	

