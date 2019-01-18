#Get the resource you want to match the tags from 
$resource = Get-AzureRmResource -ResourceName win2012 -resourceGroupName BobRG1
#Check the tags that are associcated to the resource
$resource.Tags
#Get the OS data disk, we match name and OS type must have a value so we only get OS disk
$VMOSDisk = get-azurermdisk | Where-Object {$_.ManagedBy -like "*/win2012" -and $_.OsType -ne $null} 
#Set the resource to have the same tags as the original resource.
Set-AzureRmResource -ResourceId $VMOSDisk.id -Tag $resource.Tags -Force