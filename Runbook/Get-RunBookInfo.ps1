<#


From a newbie’s point of view, I find it difficult to work out the hierarchy of devices in the Azure Portal. For example, without a lot of clicking you can’t easily tell which servers sit behind an app gateway, and in turn which app gateways are sitting behind a Traffic Manager. I could think of a few more examples but you get the idea.
User Azure sandbox subscription for testing

Add-AzureRmAccount
Set-AzureRmContext -Subscription e44872b2-e898-46d0-800f-59752a564718

#>
Get-AzureRmResourceGroup 
Get-AzureRmVirtualNetwork
#####################
#Resource Group
#####################
#Get the Resource groups and region
Get-AzureRmResourceGroup | Select-Object ResourceGroupName,@{N='Region';E={$_.Location}}

#####################
#VNET SUBNET
#####################

Get-AzureRmVirtualNetwork | Select-Object Name,Location -ExpandProperty AddressSpace 

Write-Output $ResourceGroups

Write-Output $VirtNetworks


$AzureVNets | Select-Object Name,Location -ExpandProperty AddressSpace 


$AzureVNets.AddressSpace[0]
[Array]$Output = $null

foreach ($Net in $AzureVNets)
{
    $Subnet = $Net.Subnets
    foreach ($SNet in $Subnet)
    {
        $TempNet= New-Object PSObject -Property @{
        SubnetName = $SNet.Name
        SubnetIPRange = $SNet.AddressPrefix
        VNET = $Net.Name
        }
    $Output += $TempNet
    }
}
#Output and change order of table so Subnet is first
$Output | Format-Table SubnetName,SubnetIPRange,VNET

#####################
#VMs
#####################
Get-AzureRmVM | Sort-Object ResourceGroupName


#####################
#VMs
#####################
$SQLServers = Get-AzureRmSqlServer
foreach ($server in $SQLServers)
{
    Get-AzureRmSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName | select DatabaseName,ServerName,Location,ElasticPoolName, @{N='ServiceLevel';E={$_.CurrentServiceObjectiveName}}

}

#Get load balancer information
$LoadBalancers = Get-AzureRmLoadBalancer 

$LB | Select-Object Name,FrontEndIPConfigurations.PublicIPAddress

foreach ($LB in $LoadBalancers)
{
    $LB.FrontEndIPConfigurations.PrivateIpAddress
}