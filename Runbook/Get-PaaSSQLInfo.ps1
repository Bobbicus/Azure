Add-AzureRmAccount
$SQLServers = Get-AzureRmSqlServer
foreach ($server in $SQLServers)
{
    Get-AzureRmSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName | select DatabaseName,ServerName,Location,ElasticPoolName, @{N='ServiceLevel';E={$_.CurrentServiceObjectiveName}}

}