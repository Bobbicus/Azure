
#Get azure 
Set-AzureRmContext -SubscriptionId "c935b83e-cb20-4a23-878a-8e57a53cafa3"
#Get azureVM based on user input and find the related IP address 
$VM1 = Get-AzureRmVM | Where-Object { $_.Name -eq "USSCDVIM003AD01"} | Get-AzureRmNetworkInterfaceIpConfig
$VMNICID = $VM1.NetworkProfile.NetworkInterfaces
$GetNIC =  $VMNICID.Id.split("/")
#Extract the last field which is NIC name
$NICNAme = $GetNIC | select -Last 1
$RG = $VM1.ResourceGroupName
#Get Netowrk information
$NetworkInfo = Get-AzureRmNetworkInterface -Name $NICNAme -ResourceGroupName $RG
#Display just the Private IP config
$NetworkInfo.IpConfigurations.PrivateIpAddress
 