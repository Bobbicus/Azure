<#
    .SYNOPSIS
    Azure File Backup Agent (MARS): Backup job failure checks.
       
    .DESCRIPTION
    Performs multiple (Guest OS) prerequisite checks that are required for Azure (MARS) Backup to work.

    Checks the following items:
    - IaasVmProvider Service is running.
    - WindowsAzureGuestAgent Service is running.
    - VSS Service is running.
    - Windows Firewall status..
    - MARS file version.
    - DHCP status.
    - MSSQLSERVER is installed or not.
    - .NET 4.5 is installed or not.

    Supported: Yes
    Keywords: azure,marsagent,backup,smarttickets
    Prerequisites: No
    Makes changes: Yes (if remediation is enabled).

    .EXAMPLE
    Default Full command:  Get-AzureFileBackup -Remediate Y
    - Enabling remediation will automatically restart a stopped service.

    Optional command: Get-AzureFileBackup -Remediate N
    - This will not restart any stopped services.
       
    .OUTPUTS
    Example output:

          :::::::  MARS Report  :::::::
 
General Information:
------------------------------------------------
Virtual Machine  : OH-DC-1
Operating System : Microsoft Windows Server 2016 Datacenter
IPv4 Address     : 172.16.195.4
Last Reboot Time : 11/16/2017 10:38:19
MARS Version     : 2.0.9085.0
 
Related Windows Services:
------------------------------------------------
Service: IaasVmProvider (Restarted by Remediation Engine).
- State: Running.
 
Service: WindowsAzureGuestAgent
- State: Running.
 
Service: VSS
- State: Running.

Service: Microsoft Azure Recovery Services Agent (Restarted by Remediation Engine).
- State: Running.
 
Service: Microsoft Azure Recovery Services Management Agent
- State: Running.
 
Windows Firewall Status:
------------------------------------------------
The following Profiles are enabled:
::::::::
Domain
Private
Public
::::::::

- Recommended setting: Disabled. Please check with the customer if Windows firewall should be enabled, or not.
 
Azure Backup requirements (Should read: True):
------------------------------------------------
DHCP Enabled     : True.
.NET 4.5 Present : True.
 
Failed VSS Writers Report:
------------------------------------------------
All VSS Writers are in a stable state.

Other Information:
------------------------------------------------
MSSQL Installed  : False.

Additional items to consider:
------------------------------------------------
- Deallocated VM State.
- High VM CPU% utilisation.
- Simultaneous backup jobs running at the same time.
- Retry backup job.
------------------------------------------------

Smart Ticket actions completed. Please troubleshoot further.

Troubleshoooting Azure Backup Errors:
https://social.technet.microsoft.com/wiki/contents/articles/10183.azure-backup-errors-and-events-portal.aspx

        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Oliver Hurn        :: 16-NOV-2017 :: XX-XXX   :: Bob Larkin  :: Release
    2.0     :: Oliver Hurn        :: 22-DEC-2017 :: XX-XXX   :: Bob Larkin  :: Updated output logic
    2.1     :: Oliver Hurn        :: 05-MAR-2018 :: XX-XXX   ::             :: Added Confirm Solved logic and updated Get-VSS function
#>

Param(
    [Parameter(Mandatory=$false)]$PayloadUri
    )

Function Get-AzureFileBackup
{
    Param(
    [Parameter(Mandatory=$true)]$Remediate,
    [switch]$Force
    )

    Try
    {
            #Collect ComputerName, Operating System and Local Ip address variables
            $ComputerName = (Get-CimInstance Win32_OperatingSystem).CSName
            $OSType = (Get-CimInstance Win32_OperatingSystem).Caption
            $LocalIpAddress = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]

    #Function to check if a Windows service is running and if it's not, start it.
    Function Get-rsAzureService
    {
        #Service Name paramater
        param([string]$ServiceName)

        Try
        {
            
            $arrService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($arrService -eq $null)
                { 
                    #If the Service is not present, report Missing.
                    Write-Output "Service: $($ServiceName)"
                    Write-Output "- State: Missing." 
                }
            #Remediation step: starts service is it's stopped and remediation parameter is "Y"
            elseif ($arrService.Status -ne "Running" -and $Remediate -eq "Y")
                {
                    #If Service is present, but not running, then start it.
                    Start-Service $ServiceName -ErrorAction SilentlyContinue *>$null 
                    sleep 1
                    $result = if ((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status -eq "Running")
                              {
                                "Running"
                              }
                              else 
                              {
                                "Stopped"
                              }
                    Write-Output "Service: $($ServiceName) (Restarted by Remediation Engine)."
                    Write-Output "- State: $result." 
                }
             elseif ($arrService.Status -ne "Running" -and $Remediate -eq "N")
                {

                    $result = if ((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status -eq "Running")
                              {
                                "Running"
                              }
                              else 
                              {
                                "Stopped"
                              }
                    Write-Output "Service: $($ServiceName) (Automatic remedation is disabled)."
                    Write-Output "- State: $result." 
                }
            elseif ($arrService.Status -eq "Running")
                { 
                    #If Service is present and Running, report running.
                    Write-Output "Service: $($ServiceName)"
                    Write-Output "- State: Running." 
                }
        }
        Catch
        {
                    $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }
    }

    Function Get-WinFirewall
    {
        Try
        {        
        
            $rsFirewall = Get-NetFirewallProfile -Profile Domain,Public,Private | Where-object {$_.Enabled -eq "True"} | Select-Object Name, Enabled
            $FwName = $rsFirewall.Name -join "`n"

            if  ($rsFirewall -ne $null)
                {
                    Write-Output "The following Profiles are enabled:"
                    Write-Output "::::::::"
                    Write-output "$($fwName)" 
                    Write-Output "::::::::"
                    Write-output "`n- Recommended setting: Disabled. Please check with the customer if Windows firewall should be enabled, or not."
                }
            else
                {
                    Write-output "All profiles are disabled. (Recommended Setting)."
                }
        }
        Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                Write-Output $ErrMsg 
        }
    }

    #Function to query VMSnapShot version folders under: C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.RecoveryServices.VMSnapshot\
    #Function to query file version info from cbengine.exe
    Function Get-MARSVer
    {
        Try
        {
                #Check that path exists
                $pathtest = Test-Path "C:\Program Files\Microsoft Azure Recovery Services Agent\bin\cbengine.exe"
            if ($pathtest -eq $true) 
                {
                    #if it exists, then check the file version of the cbengine.exe file
                    $var =  ((Get-ChildItem "C:\Program Files\Microsoft Azure Recovery Services Agent\bin\cbengine.exe").VersionInfo).FileVersion
                }
            else
                {
                    Write-Output "Cannot locate executable: C:\Program Files\Microsoft Azure Recovery Services Agent\bin\cbengine.exe"
                }
            return $var
        }
        Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                Write-Output $ErrMsg 
        }
    }
                #add to variable for output later
                $MARSVer = Get-MARSVer

                #Code block to: query if DHCP is enabled on the virtual NIC
                $NICs = Get-WMIObject Win32_NetworkAdapterConfiguration | Where {$_.IPEnabled -eq "TRUE"}

                #Code block to: query if a MSSQLSERVER service is present
                $MSSQL = if ((Get-Service -Name MSSQLServer -ErrorAction SilentlyContinue).Name -ne $null)
                         {
                            Write-Output "True."
                            Write-Output "`n- If you are experiencing a Backup failure because of a snapshot issue, set the following registry key:"
                            Write-output "`n  (HKEY_LOCAL_MACHINE\SOFTWARE\MICROSOFT\BCDRAGENT) 'USEVSSCOPYBACKUP'='TRUE'"
                         } 
                         else 
                         {
                         "False"
                         }

    Function Get-DotNet
    {
        Try
        {
            #Code block to: query if .NET 4.5 Framework is installed.
            Get-ChildItem "hklm:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" | Get-ItemProperty -Name Release | ForEach-Object { $_.Release -ge 394802 }
        }
        Catch
        {
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                   Write-Output $ErrMsg.
        }
    }
            $dotNet = Get-DotNet
 
    #Code block to: query last reboot time.      
    Function Get-BootTime
    {
        Try
        {
            #Get boot time
            Return (([datetime]::Now - (New-TimeSpan -Seconds (Get-WmiObject Win32_PerfFormattedData_PerfOS_System).SystemUptime)))
        }
        Catch
        {
            Return "Unknown Error."
        }
    }

            $LastReboot = Get-BootTime

    Function Get-VSS
    {        
         Try
         {
            #Query all of the VSS Writers on the system
            $RawWriters = VssAdmin List Writers
            
            #Create an array of VSS writers and sets their headers
            $Writers = @() 
            $i=0
            for ($i=0; $i -lt ($RawWriters.Count-3)/6; $i++) 
            {
                $Writer = New-Object -TypeName PSObject
                $Writer| Add-Member "ComputerName" $env:COMPUTERNAME
                $Writer| Add-Member "WriterName" $RawWriters[($i*6)+3].Split("'")[1]
                $Writer| Add-Member "StateID" $RawWriters[($i*6)+6].SubString(11,1)
                $Writer| Add-Member "StateDesc" $RawWriters[($i*6)+6].SubString(14,$RawWriters[($i*6)+6].Length - 14)
                $Writer| Add-Member "LastError" $RawWriters[($i*6)+7].SubString(15,$RawWriters[($i*6)+7].Length - 15)
                $Writers += $Writer 
            }

            #Identify Failed Writers
            $FailedWriters = $Writers | Where-Object {$_.StateId -eq 7}

            #It all writers are in a stable state, say so
            if ($FailedWriters -eq $null)
            {
                Write-Host "All VSS Writers are in a Stable State."
            }
            else
            {
                #If any state except for 'No error' is reported, then output just those writers to the final report
                Write-Host "Reboot recommended due to VSS Failed Writers found:"
                $FailedWriters
            }
        }
        Catch
        {
                    $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Could not execute: VssAdmin List Writers. Run manually instead."
        }          
    }
   
    #uncomment for testing
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\payload.json)"

    #Ingest the payload
    $object = Invoke-RestMethod -Uri $PayloadUri

    #Collect the CloudBackup Error ID 11
    $ErrorID = $object.EventID
    
    #Collect error data from EventLog
    $LastErrorEvent = Get-WinEvent "CloudBackup" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq $ErrorID} | Select -First 1

    #Collect good data from EventLog
    $LastGoodEvent = Get-WinEvent "CloudBackup" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq 3} | Select -First 1

    #Set the variables for Error Data
    $ErrorDate = $LastErrorEvent.TimeCreated
    $ErrorID = $LastErrorEvent.Id
    $BadMsg = $LastErrorEvent.Message

    #Set the variables for the Good data
    $GoodDate = $LastGoodEvent.TimeCreated
    $GoodID = $LastGoodEvent.Id
    $GoodMsg = $LastGoodEvent.Message


                    #Good output used for Confirm solving ticket
                    $OutputGood = $null
                    $OutputGood += "[TICKET_UPDATE=PUBLIC]`n"
                    $OutputGood += "[TICKET_STATUS=CONFIRM SOLVED]`n"
                    $OutputGood += "Hello Team,`n`nRackspace automation has verified that the Azure MARS Backup Agent has retried and successfully executed its most recent job, which completed successfully:"
                    $OutputGood += "`n`n--------------------------------------------------------------------`n"
                    $OutputGood += "VM            : $($ComputerName)`n"
                    $OutputGood += "OS            : $($OSType)`n"
                    $OutputGood += "IPv4 Address  : $($LocalIpAddress)`n"
                    $OutputGood += "ProviderName  : CloudBackup`n"
                    $OutputGood += "Date & Time   : $($GoodDate)`n"
                    $OutputGood += "Event ID      : $($GoodID)`n"
                    $OutputGood += "Event message : $($GoodMsg)"
                    $OutputGood += "`n----------------------------------------------------------------------------`n`n"
                    $OutputGood += "Please feel free to update this ticket if you have any questions.`n`n"
                    $OutputGood += "Kind regards,`n`nMicrosoft Azure Engineer`nRackspace Toll Free: (800) 961-4454"
 
    #Calculate current Alert State
    $AlertState = ($GoodDate) -gt ($ErrorDate)

    #Good State: pubically update ticket and return good event output
    if ($AlertState -eq $true)
    {
    $OutputGood
    }

    #Bad State: privately update ticket with diagnostics report
    elseif ($AlertState -eq $false)
    {       
        
                    #Output for Ticket Update.
                    Write-Output "[TICKET_UPDATE=PRIVATE]"
                    Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
                    Write-Output "Hello Racker,`n`nPlease use the following report to identify any misconfigured items:`n"
                    Write-Output "          :::::::  MARS Report  :::::::" 
                    Write-Output " "
                    Write-Output "General Information:"
                    Write-Output "------------------------------------------------------------"
                    Write-Output "Virtual Machine  : $($ComputerName)"
                    Write-Output "Operating System : $($OSType)"
                    Write-Output "IPv4 Address     : $($LocalIpAddress)"
                    Write-Output "Last Reboot Time : $($LastReboot.DateTime)"
                    Write-Output "MARS Version     : $($MARSVer)"
                    Write-Output " "
                    Write-Output "Related Windows Services:"
                    Write-Output "------------------------------------------------------------"
                    Get-rsAzureService -ServiceName IaasVmProvider
                    Write-Output " "
                    Get-rsAzureService -ServiceName WindowsAzureGuestAgent
                    Write-Output " "
                    Get-rsAzureService -ServiceName VSS
                    Write-Output " "
                    Get-rsAzureService -ServiceName "Microsoft Azure Recovery Services Agent"
                    Write-Output " "
                    Get-rsAzureService -ServiceName "Microsoft Azure Recovery Services Management Agent"
                    Write-Output " "
                    Write-Output "Windows Firewall Status:"
                    Write-Output "------------------------------------------------------------"
                    Get-WinFirewall
                    Write-Output " "
                    #Adds to Output if DHCP is not enabled
                    If ($NICs.DHCPEnabled -eq $false)
                    {
                    Write-Output "Azure Backup requirements (ERROR - should read: True):"
                    Write-Output "------------------------------------------------------------"
                    Write-Output "DHCP Enabled     : $($NICs.DHCPEnabled)."
                    Write-Output ".NET 4.5 Present : $($dotNet)."
                    }
                    Write-Output " "
                    Write-Output "VSS Writers Report:"
                    Write-Output "------------------------------------------------------------"
                    Get-VSS
                    #Adds to Output if MSSQL is installed
                    If ($MSSQL -eq $true)
                    {
                    Write-Output "`nOther Information:"
                    Write-Output "------------------------------------------------------------"
                    Write-Output "MSSQL Installed  : $($MSSQL)."
                    }
                    Write-Output "`nAdditional items to consider:"
                    Write-Output "------------------------------------------------------------"
                    Write-Output "- Deallocated VM State."
                    Write-Output "- VM Failed State. Check failed extension status."
                    Write-Output "- High VM CPU% utilisation."
                    Write-Output "- Simultaneous backup jobs running at the same time."
                    Write-Output "- Retry backup job."
                    Write-Output "------------------------------------------------------------`n"
                    Write-Output "Smart Ticket actions completed. Please troubleshoot further."
                    Write-Output "`nTroubleshoooting Azure Backup Errors:"
                    Write-Output "https://social.technet.microsoft.com/wiki/contents/articles/10183.azure-backup-errors-and-events-portal.aspx"
        }
    }
Catch
    {
    $ErrMsgMain = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output $ErrMsgMain 
    }
}

Get-AzureFileBackup -Remediate Y