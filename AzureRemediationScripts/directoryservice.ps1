 <#
    .SYNOPSIS
    Collects AD replication information and checks connectivity to other AD Servers
       
    .DESCRIPTION
    Collects AD replication information and checks connectivity to other AD Servers

    Supported: Yes
    Keywords: azure,ad,replication
    Prerequisites: No
    Makes changes: No

    .EXAMPLE
    Full command:  .\directoryservice.ps1
    Description: Collects AD replication information and checks connectivity to other AD Servers
       
    .OUTPUTS
    Example output:
 

        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0

    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    2.0     :: Bob Larkin         :: 27-JUL-2018 :: XX-XXX   :: ---         :: RE-written using new PS cmdlets
#>
 
    #Script Uri
    Param(
    [Parameter(Mandatory=$false)]$PayloadUri
    )     
          
    #region Payload and variables 
    #Set Test Mode: 1=Testing : 0=Production
    $testMode = 0

    if ($testMode -eq 0)
    {       
        #Ingest the payload (Production)
        $object = Invoke-RestMethod -Uri $PayloadUri
    }
    elseif ($testMode -eq 1)
    {
        #Testing payload
        $object = ConvertFrom-Json "$(get-content -Path C:\temp\ad.json)"
    }

    #Set payload variables
    #$ResourceGroupName = $object.ResourceGroup
    #$Subscription = $object.SubscriptionId
    $Computer = $object.Computer
    #$ResourceId = ($object.resourceid | Split-Path -Parent).Replace("\","/")

    #Ticket Signature
    $ticketSignature = "Kind regards,`n`n"
    #endregion

    
try
{

$ReplicationErrors = 0
$ConnectionErrors = 0
$DNSErrors = 0 
#the FormatEnumeration Limit paramater extends the default number of values dispalyed in the console used for connection report output.
$FormatEnumerationLimit = 5
#Get All Domains in the Forest
$LocalDomain = Get-ADForest -Current LocalComputer
$allDomains = $LocalDomain.Domains 
#For each domain get a list of the AD Servers
$allDCs = foreach ($Domain in $allDomains)
{
    Get-ADDomainController -Filter * -Server $Domain 
    
}
$DCConnectionTest = @()
#Get ping Results againsts 
foreach ($dc in $allDCs)
{
    #https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd772723%28v=ws.10%29
    #Test DNS port
    $Port53 = Test-NetConnection -ComputerName $dc.name -Port 53 -WarningAction SilentlyContinue
    if ($Port53.TcpTestSucceeded -ne "True")
    {
        $ConnectionErrors += 1
        $Port53Connection = "53-N"
    }
    if ($Port53.TcpTestSucceeded -eq "True")
    {
        $Port53Connection = "53-Y"
    }
    #Test Replication port
    $Port135 = Test-NetConnection -ComputerName $dc.name -Port 135 -WarningAction SilentlyContinue
    if ($Port135.TcpTestSucceeded -ne "True")
    {
        $ConnectionErrors += 1
        $Port135Connection = "135-N"
    }
    if ($Port135.TcpTestSucceeded -eq "True")
    {
        $Port135Connection = "135-Y"
    }
    #Test Replication, User and Computer Authentication
    $Port445 = Test-NetConnection -ComputerName $dc.name -Port 445 -WarningAction SilentlyContinue
    if ($Port445.TcpTestSucceeded -ne "True")
    {
        $ConnectionErrors += 1
        $Port445Connection = "445-N"
    }
    if ($Port445.TcpTestSucceeded -eq "True")
    {
        $Port445Connection = "445-Y"
    }
    #Directory, Replication, User and Computer Authentication, Group Policy, Trusts
    $Port389 = Test-NetConnection -ComputerName $dc.name -Port 389 -WarningAction SilentlyContinue
    if ($Port389.TcpTestSucceeded -ne "True")
    {
        $ConnectionErrors += 1
        $Port389Connection = "389-N"
    }
    if ($Port389.TcpTestSucceeded -eq "True")
    {
        $Port389Connection = "389-Y"
    }
    #Test kerberos
    $port88 = Test-NetConnection -ComputerName $dc.name -Port 88 -WarningAction SilentlyContinue
    if ($Port88.TcpTestSucceeded -ne "True")
    {
        $ConnectionErrors += 1
        $Port88Connection = "88-N"
    }
    if ($Port88.TcpTestSucceeded -eq "True")
    {
        $Port88Connection = "88-Y"
    }
    $ConnectionTestResults = @($Port53Connection,$Port135Connection,$Port445Connection,$Port389Connection,$Port88Connection)
                   
    $item = New-Object PSObject -property @{}
    $item | Add-member -MemberType NoteProperty -Name "Server" -Value $Port53.ComputerName
    #
    #REVIEW REVIEW REVIEW
    #DO I add all source and desitination IPs or safe to assume it uses same for each test. I think it should be ok
    #
    $item | Add-member -MemberType NoteProperty -Name "Remote Address" -Value $Port53.RemoteAddress
    $item | Add-member -MemberType NoteProperty -Name "Source Address" -Value $Port53.SourceAddress
    $item | Add-member -MemberType NoteProperty -Name "Port Connections working Y/N" -Value $ConnectionTestResults

    $DCConnectionTest +=$item
}

#Create the Connection report, check if there are any failures from the connection tests
$ConnectionReportOutput = if ($ConnectionErrors  -gt 0)
{
    Write-Output "Errors were found during the Port Connection tests:`n"
    
    #Write-Output $DCConnectionTest 
    foreach ($ConnectionResult in $DCConnectionTest)
    {
    $Errornum = 0
        $PortResults = $ConnectionResult."Port Connections working Y/N" 

        foreach ($PortTest in $PortResults)
        {
        #$PortTest
            if ($PortTest -like "*N")
            {
                $Errornum  += 1
                #$Errornum 
           }
        }
        if ($Errornum -gt 0)
        {
            Write-Output ($ConnectionResult | Format-List | Out-String).Trim()
        }
        elseif ($Errornum -eq 0)
        {
            Write-Output $("`nServer                       : "+$ConnectionResult.Server+"`nPort Connections Comment     : All AD network connectivity tests were successful.`n")
        }
        
   }
}
elseif ($ConnectionErrors  -eq 0)
{
    Write-Output "There were no errors with the connection tests."
}

#Get full replication information
$Replicationstate = Get-ADReplicationPartnerMetadata -Target * -Partition *  -ErrorAction SilentlyContinue | Select-Object Server,Partition,Partner,ConsecutiveReplicationFailures,LastReplicationSuccess,LastReplicationResult 

#Get todays Date and create a time windows.  So anything newer than last 2 days may not indicate a replciation issue
$CurrentDateTime = (Get-Date).AddDays(-2)

#From replication information check each one, the loop extracts the partner DC from the full partner string.  We then compare this to the date above
#We can fine tune this at the moment it is the last 2 days to see if there is a recent replciation state since this date
$ReplicationResults = @()
foreach ($result in $Replicationstate)
{
    $Partition = $result.Partition.Split(",")
    #To reduce output I exclude the check on the schema and configuration partitions and just focus on the root.  
    #We can review results when this is live to see if this information is enough or we need to add in other partitions.
    if ($Partition[0] -ne "CN=Configuration" -and $Partition[0] -ne "CN=Schema")
    {

        $Partner = $result.Partner.Split(",")[1]
        #Compare Last Replication Success to our reference date to see if there has been recent replications.
        if ($result.LastReplicationSuccess -gt $CurrentDateTime)
        {
            $RecentReplication = "True"
            $ADServerName = $result.Server.Split(".")[0]
            #Only add replication data for failed replication partners
            $item = New-Object PSObject -property @{}
            $item | Add-member -MemberType NoteProperty -Name "Server" -Value $ADServerName
            #$item | Add-member -MemberType NoteProperty -Name "Partition" -Value $result.Partition
            $item | Add-member -MemberType NoteProperty -Name "Partner"  -Value $Partner
            #$item | Add-member -MemberType NoteProperty -Name "Consecutive Replication Failures" -Value $result.ConsecutiveReplicationFailures
            $item | Add-member -MemberType NoteProperty -Name "Last Replication Success" -Value $result.LastReplicationSuccess
            #$item | Add-member -MemberType NoteProperty -Name "Last Replication Result" -Value $result.LastReplicationResult
            #$item | Add-member -MemberType NoteProperty -Name "Replication within last 24 Hours" -Value $RecentReplication
            $ReplicationResults +=$item
        }
        else
        {
            $RecentReplication = "False"
            $ReplicationErrors += 1
            $ADServerName = $result.Server.Split(".")[0]
            #Only add replication data for failed replication partners
            $item = New-Object PSObject -property @{}
            $item | Add-member -MemberType NoteProperty -Name "Server" -Value $ADServerName
            $item | Add-member -MemberType NoteProperty -Name "Partition" -Value $result.Partition
            $item | Add-member -MemberType NoteProperty -Name "Partner"  -Value $Partner
            $item | Add-member -MemberType NoteProperty -Name "Consecutive Replication Failures" -Value $result.ConsecutiveReplicationFailures
            $item | Add-member -MemberType NoteProperty -Name "Last Replication Success" -Value $result.LastReplicationSuccess
            #$item | Add-member -MemberType NoteProperty -Name "Last Replication Result" -Value $result.LastReplicationResult
            $item | Add-member -MemberType NoteProperty -Name "Replication within last 24 Hours" -Value $RecentReplication
            $ReplicationResults +=$item
        }
    }           

}


#Get state of DNS service
$DNSOutput = @()
$DNSService = Get-Service -Name DNS
if ($DNSService.Status -ne "Running")
   {
        $DNSErrors += 1
   }

        $DNSOutput += "--------------------------------"
        $DNSOutput +=  "DNS Server Service:"
        $DNSOutput +=  "--------------------------------`n"
        if ($DNSErrors -gt 0)
        {
            $DNSOutput +=  "`Service Status: Not Running on $Computer."
        }
        elseif ($DNSErrors -eq 0)
        {
            $DNSOutput +=  "`Service Status: Running on $Computer."
        }
       
#Get status of Windows Firewall profiles.  Profiles should be disable or we will flag this
Function Get-WinFwStatus
        {
            Try
            {
                $WinFirewall = Get-NetFirewallProfile -Profile Domain,Public,Private | Where-object {$_.Enabled -eq "True"} | Select-Object Name, Enabled
                If ($WinFirewall -ne $null)
                {
                    $FwName = $WinFirewall.Name -join "`n"
                }
                else
                {
                    $FwName = "None"
                }
            }
            Catch
            {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                Write-Output "Script failed to run:`n"
                Write-Output $ErrMsg
            }
            return $FwName
}
$WinFwStatus = Get-WinFwStatus
$WinFWOutput =  @()
if ($WinFwStatus -eq "None")
    {
        $WinFWOutput += "--------------------------------"
        $WinFWOutput += "Windows Firewall Status:"
        $WinFWOutput += "--------------------------------`n"
        $WinFWOutput += "All Windows Firewall profiles are disabled.`n"
    }
    #If Windows Firewall is On include in output
    if ($WinFwStatus -ne "None")
    {
        $WinFWOutput += "--------------------------------"
        $WinFWOutput += "Windows Firewall Status:"
        $WinFWOutput += "--------------------------------"
        $WinFWOutput += "Enabled Profiles:`n"
        $WinFWOutput += "$($WinFwStatus)`n"
    }

    #Check all replication and connection tests are now showing as succesful for a healthy report 
    if ($ReplicationErrors -eq 0 -and $ConnectionErrors -eq 0 -and $DNSErrors -eq 0)
    {
        Write-Output "Hello Team,`n`n"
        Write-Output "Smart Ticket Automation has confirmed that AD replication and AD VM connectivity tests are reporting as healthy to all Domain controllers. This indicates any replication issues were resolved since this alert was raised:`n"
        Write-Output "Active Directory Replication Summary for: $($Computer)"
        Write-Output "---------------------------------------------------------------------------------"
        $ReplicationResults
        Write-Output "`nConnectivity to partner AD Servers was successful on ports:"
        Write-Output "53,135,445,389,88`n"      
        Write-Output $WinFWOutput
        Write-Output $DNSOutput
        Write-Output "`n"
        Write-Output "As AD synchronisation and connectivity tests are showing replication is now working. We will mark this ticket status as Confirm Solved, if you have any questions please let us know.`n" 
        Write-Output "$($ticketSignature)"

    }
    #If any of the tests report errors we produce an error report with the details for a tech to investigate.
    elseif ($ReplicationErrors -gt 0 -or $ConnectionErrors -gt 0 -or  $DNSErrors -gt 0)
    {
        Write-Output "Hello Team,`n`nSmart Ticket Automation has performed a series of AD-related tests to aid in troubleshooting. Please review the following report:`n"
        Write-Output "--------------------------------"
        Write-Output "AD Replication failures:"
        Write-Output "--------------------------------`n"
        if ($ReplicationErrors -gt 0)
        {
            Write-Output "Errors were reported in the Replication tests:"
            Write-Output $ReplicationResults
        }
        elseif ($ReplicationErrors -eq 0)
        {
            Write-Output "No errors were reported in the Replication tests."
        }
        Write-Output "`n--------------------------------"
        Write-Output "Network Port Connections:"
        Write-Output "--------------------------------`n"
        Write-Output $ConnectionReportOutput | Format-List
        Write-Output ""
        Write-Output $WinFWOutput
        Write-Output $DNSOutput 
        Write-Output "`n`nAn engineer will review the failures in this report and begin troubleshooting accordingly.`n`n"
        Write-Output "$($ticketSignature)"
     }
}
catch
{
    $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
    Write-Output $ErrMsg.
}