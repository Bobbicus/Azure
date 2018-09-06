$RG1          = "NEU-RSG-ALL-PRD"
$Connection1 = "RackspaceToAzure"
$connection1  = Get-AzureRmVirtualNetworkGatewayConnection -Name $Connection1 -ResourceGroupName $RG1

$ciscoasapolicy   = New-AzureRmIpsecPolicy -IkeEncryption AES256 -IkeIntegrity SHA1 -DhGroup DHGroup24 -IpsecEncryption AES256 -IpsecIntegrity SHA1 -PfsGroup PFS24 -SALifeTimeSeconds 7200 -SADataSizeKilobytes 102400000

Set-AzureRmVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection1 -IpsecPolicies $ciscoasapolicy