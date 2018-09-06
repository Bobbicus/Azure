
$RGname 
#Method1
#This method is slower than method 2.  In this you have to get all VMs then do the where-object
$VMNames1 = ("VM1","VMSQL1","DEV-WEB2")
foreach ($VM1 in $VMNames1)
{
    Get-AzureRmVM -status -ResourceGroupName $RGname | Select Name,Location,ResourceGroupName,PowerState | Where-Object { $_.Name -eq $VM1}
}

#Method two provide VM at begniong filter at start.  save to variable and then search this for fields you want
$VMNames = ("SCU-360-CCH","SCU-360-DB2-1","SCU-360-DB2-2","SCU-360-DC-1","SCU-360-DC-2","SCU-360-DNS-2","SCU-360-DNS-3","SCU-360-Portals-1","SCU-360-Portals-2","SCU-LMS64-1","SCU-LMS64-SERVICE-2","SCU-PROD-GW-2","SCU-QA-GATEWAY-1", 
"SCU-QA-UDP-1","SCU-RAILGUN","SCU-SQL-C1N1.360training.com","SCU-SQL-C2N2")


$VMList = foreach ($VM in $VMNames)
{
    Get-AzureRmVM -Name $VM -status -ResourceGroupName  $RGname
}
foreach ($VM2 in $VMList)
{
Write-Output $($VM2.Name + " : "+ $VM2.Statuses.DisplayStatus[1])
#Write-Output $VM2.Name
#Write-Output $VM2.Statuses.DisplayStatus[1]
#Write-Output " "
}

#Powerstate only seems to be available for Method 1


#when you dont know RG name
foreach ($VM in $VMNames)
{

$ServerInfo = Find-AzureRmResource -ResourceNameEquals $VM -ResourceType Microsoft.Compute/virtualMachines
if ($ServerInfo)
{
    $VMRG = $ServerInfo.ResourceGroupName
    $VMState = Get-AzureRmVM -Name $VM -ResourceGroupName $VMRG -Status
    $VMState.Name
    $VMState.Statuses.displaystatus[1]

}
}

