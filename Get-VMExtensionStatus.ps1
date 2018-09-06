 
 Add-AzureRmAccount 
 <#Get the VM extenstion and check the status so you can see more details.  Need to change extention number to match one you are investigating.

For Example GUi may just show transitioning but status will show somenthing like this

Code          : ProvisioningState/transitioning
Level         : Info
DisplayStatus : Transitioning
Message       : Downloading files from storage
Time          : 

#>
 (Get-AzureRmVM -Status -Name TST-VM-01 -ResourceGroupName NEU-COMPANY-RSG-TST).Extensions[6].Statuses
