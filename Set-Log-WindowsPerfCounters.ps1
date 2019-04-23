#This script will add the common Windows perfmon counters to the the OMS workspace specified.

$WorkspaceName = "orx-oms-stg"
$ResourceGroup = "orx-oms-stg-rg01"

# Windows PerfLogicalDisk(*)\Avg. Disk sec/Read
$WinPerfCounters = @("LogicalDisk(*)\Current Disk Queue Length",`
"LogicalDisk(*)\Avg. Disk sec/Write",`
"LogicalDisk(*)\Disk Reads/sec",`
"LogicalDisk(*)\Disk Transfers/sec",`
"LogicalDisk(*)\Disk Writes/sec",`
"LogicalDisk(*)\Free Megabytes",`
"LogicalDisk(*)\% Free Space",`
"Memory(*)\Available MBytes",`
"Memory(*)\% Committed Bytes In Use",`
"Network Adapter(*)\Bytes Received/sec",`
"Network Adapter(*)\Bytes Sent/sec",`
"Network Interface(*)\Bytes Total/sec",`
"Processor(_Total)\% Processor Time",`
"System(*)\Processor Queue Length")


$int = 0
foreach ($Counter in $WinPerfCounters)
{
    $int +=1
    $counterinfo = $counter.split("(")
    $counterinfo = $counterinfo.split(")")
    $counterinfo = $counterinfo.split("\")


    $ObjectName = $counterinfo[0]   
    $IntanceName = $counterinfo[1]
    $CounterName = $counterinfo[3]
    $Name = $ObjectName+$int
    Write-Output  $("Obj="+$ObjectName)
    Write-Output  $("Instance="+$IntanceName)
    Write-Output $("Counter="+$CounterName)
    Write-Output $Name
    New-AzureRmOperationalInsightsWindowsPerformanceCounterDataSource -ResourceGroupName $ResourceGroup -WorkspaceName $WorkspaceName -ObjectName $ObjectName -InstanceName $IntanceName -CounterName $CounterName -IntervalSeconds 20 -Name $Name
}

	
	
	
	
	
	
	

