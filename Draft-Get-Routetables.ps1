add-azurermaccount
platform-rg-uks-nonprod
$AzureVNets = Get-AzureRmVirtualNetwork -ResourceGroupName "platform-rg-uks-nonprod" -Name "platform-vnet01-uks-nonprod"
$AzureVNets

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
        RT = $Net.TagsTable
        }
    $Output += $TempNet
    }
}

$Output

$SN = Get-AzureRmVirtualNetworkSubnetConfig -name "platform-public-sn01-uks-nonprod"  -VirtualNetwork $AzureVNets 
$SN.RouteTable