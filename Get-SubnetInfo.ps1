saam -portalonly 896945

$AzureVNets = Get-AzureRmVirtualNetwork


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

$Output