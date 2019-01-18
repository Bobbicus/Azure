<#
    .SYNOPSIS
    Smart Ticket remediation script for Azure Recovery Service Vault.
       
    .DESCRIPTION
    Ingests JSON payload and based on $FailureDetails variable, performs different remediation actions and generates a CORE Ticket output.

    Supported: Yes
    Keywords: azure,malware,recovery service vault,smarttickets
    Prerequisites: No
    Makes changes: Yes

    .EXAMPLE
    Full command:  .\raxbackupvaulterror.ps1
    Description: Smart Ticket script - payload aware.
       
    .OUTPUTS
    Example output:
 
    Hello Team,

    This error is thrown if there is a problem with the VM Agent or network access to the Azure infrastructure is blocked in some way. Automated remediation has attempted to update the Windows Azure Guest Agent and restart each Azure-related Backup service, as well as, set its start-u
    p type to 'Automatic':

    Guest OS Information:
    ------------------------------------------------------------
    Virtual Machine  : OH-DC-1
    Operating System : Microsoft Windows Server 2016 Datacenter
    IPv4 Address     : 172.16.195.4
    Last Reboot Time : Monday, January 8, 2018 8:35:01 AM
    ------------------------------------------------------------

    Windows Azure Guest Agent Update:
    ------------------------------------------------------------------------------------------------
    Product: Windows Azure VM Agent - 2.7.41491.872 -- Configuration completed successfully.
    ------------------------------------------------------------------------------------------------

    Azure Backup Services Report:
    ------------------------------------------------------------------------------------------------
     Service: WindowsAzureGuestAgent (Restarted by Remediation Engine).
     - State: Running.

     Service: IaasVmProvider (Restarted by Remediation Engine).
     - State: Running.

     Service: VSS (Restarted by Remediation Engine).
     - State: Running.
    ------------------------------------------------------------------------------------------------

    Guest OS remediation complete. Azure platform remediation initiated, another update will follow shortly...

    Kind regards,

    Smart Ticket Automation.

        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0

    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Oliver Hurn        :: 08-JUN-2017 :: XX-XXX   :: Bob Larkin  :: Release
    1.1     :: Oliver Hurn        :: 28-JUN-2017 :: XX-XXX   :: ---         :: $ResourceGroup bug fixes
#>

    #Script Uri
    Param(
    [Parameter(Mandatory=$false)]$PayloadUri
    )
    #>

    #region Testing
    #uncomment for testing
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\rsv\vmagent.json)"
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\rsv\snapshot.json)"
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\rsv\vss.json)"
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\rsv\nsg.json)"
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\rsv\VMState.json)"
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\rsv\largedisk.json)"
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\rsv\else.json)"
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\rsv\complus.json)"
    #endregion

try
{

    #region Script Variables
    #Remediation Switch
    $Remediate = "Y"

    #Ingest the payload
    $object = Invoke-RestMethod -Uri $PayloadUri

    #Payload variables
    $FailureDetails = $object.Properties.FailureDetails
    $VMName = $object.Computer
    $Rsg = $object.ResourceGroup
    $RSV = $object.ResourceId | Split-Path -Leaf
    $RSVDateTime = $object.TimeGenerated
    $ResourceId = $object.ResourceId

    #Guest OS variables
    $ComputerName = (Get-CimInstance Win32_OperatingSystem).CSName
    $OSType = (Get-CimInstance Win32_OperatingSystem).Caption
    $LocalIpAddress = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1] 
    #endregion

    $ticketSignature = "Kind regards,`n`nSmart Ticket Automation`nRackspace Toll Free (US): 1800 961 4454`n                    (UK): 0800 032 1667"

    #region Create Functions Section
    #Install Windows Azure Guest Agent Function
    Function Install-WinAzureGuestAgent
    {
        Try
        {

            #Set temp installation path
            $vmAgentInstallationPath = "C:\rs-pkgs\VmAgentInstaller"

            #Create Directory
            New-Item -ItemType Directory -Force -Path $vmAgentInstallationPath | Out-Null

            #Naviagate to installation path
            cd $vmAgentInstallationPath
    
            #Download installation file
            (New-Object system.net.WebClient).DownloadFile("http://go.microsoft.com/fwlink/p/?LinkId=394789", "$vmAgentInstallationPath\VMAgent.msi");

            #Run installer
            Start-Process -FilePath "VMAgent.msi" -ArgumentList "/quiet /l* vmagent-installation.log" -Wait

            #Read Log file and store in variable
            $content = Get-Content .\vmagent-installation.log -Tail 10
    
            #Confirm Success or Failure
            if ($content -like "*Configuration failed*")
            {
                #Failed Install
                $installOutcome = $content[0].Substring(32)
            }
            elseif ($content -notlike "*Configuration failed*")
            {
                #Successfull install
                $installOutcome = $content[5].Substring(32)
            }
            else
            {
                 #Error
                 $installOutcome = "No Log File found in: $($vmAgentInstallationPath)"
            }
        }
        Catch
        {
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
            Write-Output "Script failed to run"
            Write-Output $ErrMsg 
        }
        return $installOutcome
    }

    #Restart Services Function
    Function Restart-rsAzureService
    {
            #Service Name paramater
            param([string]$ServiceName)

            Try
            {
            
                $arrService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
                if ($arrService -eq $null)
                    { 
                        #If the Service is not present, report Missing.
                        Write-Output " Service: $($ServiceName)`n"
                        Write-Output "- State: Missing." 
                    }
                #Remediation step: starts service is it's stopped and remediation parameter is "Y"
                elseif ($arrService.Status -ne "Paused" -and $Remediate -eq "Y")
                    {
                        #If Service is present, but not running, then start it.
                        Set-Service -Name $ServiceName -StartupType Automatic -ErrorAction SilentlyContinue
                        Restart-Service $ServiceName -ErrorAction SilentlyContinue -Force *>$null
                        sleep 5
                        $result = (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status

                        Write-Output " Service: $($ServiceName) (Restarted by Remediation Engine).`n"
                        Write-Output "- State: $result." 
                    }
                 elseif ($arrService.Status -ne "Running" -and $Remediate -eq "N")
                    {

                        $result = (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status

                        Write-Output " Service: $($ServiceName) (Automatic remediation is disabled).`n"
                        Write-Output "- State: $result." 
                    }

            }
            Catch
            {
                        $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                        Write-Output "Script failed to run"
                        Write-Output $ErrMsg 
            }
        }

    #VSS Writer Function
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

                #Identify Failed Writers [7] - (Good state = 1)
                $FailedWriters = $Writers | Where-Object {$_.StateId -eq 7}

                if ($Writers -eq $null)
                {
                    Write-Output "vssadmin list writers command returned `$null output."
                }   



                #If all writers are in a stable state, say so
                elseif ($FailedWriters -eq $null)
                {
                    Write-Output "All VSS Writers are in a Stable State."
                }
                else
                {
                    #If any state except for 'No error' is reported, then output just those writers to the final report
                    #Write-Host "VSS Writer errors found:"
                    $FailedWriters
                }
            }
            Catch
            {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                Write-Output "Could not execute: VssAdmin List Writers. Run manually instead."
            }          
        }

        #DHCP Check
        #region
        $DHCPStatus = Get-WMIObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq "TRUE"}
        #endregion

        #Proxy Check
        #region
        $ProxyCheck = ([System.Net.WebProxy]::GetDefaultProxy()).Address
        if ($ProxyCheck -ne $null)
        {
            $Proxy = $ProxyCheck
        }
        else
        {
            $Proxy = "Not configured."
        }
        #endregion

        #Last Reboot Function    
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

        #Windows Firewall Check
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

        #Create variable for Windows Firewall check
        $WinFwStatus = Get-WinFwStatus
    #endregion

    #region Decision logic and Ticket Output Section

    #VMAgent Error
    if ($FailureDetails -like "*Ensure the VM has network connectivity and the VM agent is latest and running.*" -or $FailureDetails -like "*Could not communicate with the VM agent for snapshot status*")
    {
        #Update VM Agent version
        $WinAzureGuestAgentInstall = Install-WinAzureGuestAgent

        #perform service restart
        $rsvService1 = Restart-rsAzureService -ServiceName WindowsAzureGuestAgent
        $rsvService2 = Restart-rsAzureService -ServiceName IaasVmProvider
        $rsvService3 = Restart-rsAzureService -ServiceName VSS

        #region VMAgentOutput
        $VMAgentOutput = $null
        $VMAgentOutput += "Hello Team,`n`nThis error is thrown if there is a problem with the VM Agent or network access to the Azure infrastructure is blocked in some way. Automated remediation has attempted to update the Windows Azure Guest Agent and restart each Azure-related Backup service, as well as, set its start-up type to 'Automatic':"
        $VMAgentOutput += "`n`nGuest OS Information:`n----------------------------------------------------------------------------------------"
        $VMAgentOutput += "`nVirtual Machine  : $($ComputerName)"
        $VMAgentOutput += "`nOperating System : $($OSType)"
        $VMAgentOutput += "`nIPv4 Address     : $($LocalIpAddress)"
        $VMAgentOutput += "`nLast Reboot Time : $($LastReboot.DateTime)"
        $VMAgentOutput += "`n----------------------------------------------------------------------------------------"
        $VMAgentOutput += "`n`nWindows Azure Guest Agent Update:`n----------------------------------------------------------------------------------------`n"
        $VMAgentOutput += "$($WinAzureGuestAgentInstall)"
        $VMAgentOutput += "`n----------------------------------------------------------------------------------------"
        $VMAgentOutput += "`n`nAzure Backup Services Report:`n----------------------------------------------------------------------------------------`n"
        $VMAgentOutput += "$($rsvService1)`n`n"
        $VMAgentOutput += "$($rsvService2)`n`n"
        $VMAgentOutput += "$($rsvService3)"
        $VMAgentOutput += "`n----------------------------------------------------------------------------------------`n`n"
        #Confirm Agent installation success and kick off PaaS remediation
        if (($WinAzureGuestAgentInstall).Contains("successfully"))
        {
            $VMAgentOutput += "Guest OS remediation complete. Azure platform remediation initiated, another update will follow shortly.`n`n"
            $VMAgentOutput += "$($ticketSignature)"
            $VMAgentOutput += "[TICKET_UPDATE=PUBLIC]"
            $VMAgentOutput += "[TICKET_STATUS=ALERT RECEIVED]"
            $VMAgentOutput += "[TICKET_PAAS_REMEDIATION=TRUE]"
            $VMAgentOutput += "[TICKET_PAAS_DEVICE=$($ResourceId)]"
        }
        #Agent install failure, do not kick off paas remediation
        else
        {
            $VMAgentOutput += "Windows Azure Guest Agent update failed, please remediate manually. Logs can be found in directory: C:\rs-pkgs\VmAgentInstaller\`n`n"
            $VMAgentOutput += "$($ticketSignature)"
            $VMAgentOutput += "[TICKET_UPDATE=PRIVATE]"
            $VMAgentOutput += "[TICKET_STATUS=ALERT RECEIVED]"
        }
        #endregion
        
        $VMAgentOutput
    }
    #VSS Writer Error
    elseif ($FailureDetails -like "*Snapshot operation failed due to VSS*")
    {
        #Restart VSS Service
        $VSSService1 = Restart-rsAzureService -ServiceName VSS
        
        #Query VSS Writers
        $VSS = Get-VSS    

        #region VSSOutput
        $VssOutput = $null
        $VssOutput += "Hello Team,`n`nRackspace Automation has restarted the Windows VSS Service and subsequently queried the VSS Writers present on VM: $($ComputerName), which are potentially causing Azure VM-Level Backup jobs to fail:"
        $VssOutput += "`n`nGuest OS Information:`n------------------------------------------------------------"
        $VssOutput += "`nVirtual Machine  : $($ComputerName)"
        $VssOutput += "`nOperating System : $($OSType)"
        $VssOutput += "`nIPv4 Address     : $($LocalIpAddress)"
        $VssOutput += "`nLast Reboot Time : $($LastReboot.DateTime)"
        $VssOutput += "`n------------------------------------------------------------"
        $VssOutput += "`n`nWindows Services Report:`n------------------------------------------------------------`n"
        $VssOutput += "$($VSSService1)"
        $VssOutput += "`n------------------------------------------------------------"
        if ($VSS -ne "All VSS Writers are in a Stable State.")
        { 
            $VssOutput += "`n`nFailed VSS Writer(s) Report:`n------------------------------------------------------------"
            if ($VSS -eq "vssadmin list writers command returned `$null output.")
            {
                $VssOutput += "`n$($VSS)"
            }
            else
            {
                $VssOutput += "`n$($VSS | Select-Object WriterName, StateDesc, LastError | Format-Table -AutoSize | Out-String)"
            }
            $VssOutput += "`n------------------------------------------------------------`n`n"
            $VssOutput += "Microsoft's next recommendation is to reboot the VM. Please can you update this ticket with a preferred date, time and timezone to perform a reboot? Alternatively, please feel free to do this yourself and update us accordingly.`n`n"
            $VssOutput += "$($ticketSignature)"
            $VssOutput += "[TICKET_UPDATE=PUBLIC]"
            $VssOutput += "[TICKET_STATUS=REQUIRE FEEDBACK]"
            $VssOutput += "[TICKET_PAAS_REMEDIATION=TRUE]"
            $VssOutput += "[TICKET_PAAS_DEVICE=$($ResourceId)]"
        }
        elseif ($VSS -eq "All VSS Writers are in a Stable State.")
        {       
            $VssOutput += "`n`nGuest OS remediation complete. Azure platform remediation initiated, another update will follow shortly.`n`n"
            $VssOutput += "$($ticketSignature)"
            $VssOutput += "[TICKET_UPDATE=PUBLIC]"
            $VssOutput += "[TICKET_STATUS=ALERT RECEIVED]"
            $VssOutput += "[TICKET_PAAS_REMEDIATION=TRUE]"
            $VssOutput += "[TICKET_PAAS_DEVICE=$($ResourceId)]"
        }
        #endregion        
                
        #Output
        $VssOutput
    }
    #NSG Whitelist Error
    elseif ($FailureDetails -like "*For snapshot to succeed, either whitelist Azure datacenter IP ranges*")
    {
        #region NSGOutput
        $NSGOutput = $null
        $NSGOutput += "[TICKET_UPDATE=PUBLIC]"
        $NSGOutput += "[TICKET_STATUS=ALERT RECEIVED]"
        $NSGOutput += "[TICKET_PAAS_REMEDIATION=TRUE]"
        $NSGOutput += "[TICKET_PAAS_DEVICE=$($ResourceId)]`n" 
        $NSGOutput += "Hello Team,`n`nInternet connectivity is required for the VM snapshot extension to take a snapshot of the underlying Virtual Machine disks. OutBound Network Security Group (NSG) rules protecting VM: $($ComputerName) may be denying outbound network access to Azure datacenter IP ranges."
        $NSGOutput += "`n`nMicrosoft Article:`n----------------------------------------------------------------------------------------------------------------------------------------`n"
        $NSGOutput += "https://docs.microsoft.com/en-us/azure/backup/backup-azure-troubleshoot-vm-backup-fails-snapshot-timeout#the-vm-has-no-internet-access"
        $NSGOutput += "`n----------------------------------------------------------------------------------------------------------------------------------------`n`n"
        $NSGOutput += "Guest OS Information:`n------------------------------------------------------------"
        $NSGOutput += "`nVirtual Machine  : $($ComputerName)"
        $NSGOutput += "`nOperating System : $($OSType)"
        $NSGOutput += "`nIPv4 Address     : $($LocalIpAddress)"
        $NSGOutput += "`nLast Reboot Time : $($LastReboot.DateTime)"
        $NSGOutput += "`n------------------------------------------------------------`n`n"
        $NSGOutput += "Guest OS checks performed:`n"
        $NSGOutput += "-------------------------------------`n"
        $NSGOutput += "- Windows Firewall`n"
        $NSGOutput += "- DHCP`n"
        $NSGOutput += "- Web Proxy`n`n"
        $NSGOutput += "Potential problems:`n`n"
        #If all checks are good, Windows firewall: off, DHCP: on and Proxy: off then output
        if ($WinFwStatus -eq "None" -and $DHCPStatus.DHCPEnabled -eq $true -and $Proxy -eq "Not configured.")
        {
            $NSGOutput += "- No Guest OS problems found.`n`n"
        }
        #If Windows Firewall is On include in output
        if ($WinFwStatus -ne "None")
        {
            $NSGOutput += "Windows Firewall Profiles (Enabled):`n"
            $NSGOutput += "-------------------------------------`n"
            $NSGOutput += "$($WinFwStatus)`n"
            $NSGOutput += "-------------------------------------`n`n"
        }
        #If DHCP is off including in output
        if ($DHCPStatus.DHCPEnabled -ne $true)
        {
            $NSGOutput += "DHCP (Enabled):`n"
            $NSGOutput += "-------------------------------------`n"
            $NSGOutput += "$($DHCPStatus.DHCPEnabled)`n"
            $NSGOutput += "-------------------------------------`n`n"
        }
        #if proxy is configured include in output
        if ($Proxy -ne "Not configured.")
        {
            $NSGOutput += "Web Proxy Address:`n"
            $NSGOutput += "-------------------------------------`n"
            $NSGOutput += "$($Proxy)`n"
            $NSGOutput += "-------------------------------------`n`n"
        }
        $NSGOutput += "Guest OS remediation complete. Retrieving Outbound Network Security Rules associated with this VM; another update will follow shortly.`n`n"
        $NSGOutput += "$($ticketSignature)"
        #endregion        
        
        #Output
        $NSGOutput
        }
    #VM Failed State Error
    elseif ($FailureDetails -like "*VM is in Failed Provisioning State*")
    {
        #perform service restart
        $rsvService1 = Restart-rsAzureService -ServiceName WindowsAzureGuestAgent
        $rsvService2 = Restart-rsAzureService -ServiceName IaasVmProvider
        $rsvService3 = Restart-rsAzureService -ServiceName VSS

        #region VMStateOutput
        $VMStateOutput = $null
        $VMStateOutput += "[TICKET_UPDATE=PRIVATE]"
        $VMStateOutput += "[TICKET_STATUS=ALERT RECEIVED]"
        $VMStateOutput += "[TICKET_PAAS_REMEDIATION=TRUE]"
        $VMStateOutput += "[TICKET_PAAS_DEVICE=$($ResourceId)]`n" 
        $VMStateOutput += "Hello Team,`n`nThis occurs when one or more of the VM's Extensions are in a 'Failed' provisioning state. Automated remediation has restarted each Azure related Backup service and set its start-up type to 'Automatic':"
        $VMStateOutput += "`n`nGuest OS Information:`n-------------------------------------------------------------------"
        $VMStateOutput += "`nVirtual Machine  : $($ComputerName)"
        $VMStateOutput += "`nOperating System : $($OSType)"
        $VMStateOutput += "`nIPv4 Address     : $($LocalIpAddress)"
        $VMStateOutput += "`nLast Reboot Time : $($LastReboot.DateTime)"
        $VMStateOutput += "`n-------------------------------------------------------------------"
        $VMStateOutput += "`n`nAzure Backup Services Report:`n-------------------------------------------------------------------`n"
        $VMStateOutput += "$($rsvService1)`n`n"
        $VMStateOutput += "$($rsvService2)`n`n"
        $VMStateOutput += "$($rsvService3)"
        $VMStateOutput += "`n-------------------------------------------------------------------`n`n"
        $VMStateOutput += "Guest OS remediation complete. Azure platform remediation is checking the status of all installed extensions and the VM's Powerstate; another update will follow shortly.`n`n"
        $VMStateOutput += "$($ticketSignature)"
        #endregion

        #Output
        $VMStateOutput
    }
    #Large Disk Error
    elseif ($FailureDetails -like "*The specified Disk Configuration is not supported*"-or $FailureDetails -like "*Azure Backup does not support disk sizes greater than 1023GB*")
    {
        #region LargeDiskOutput
        $LargeDiskOutput = $null
        $LargeDiskOutput += "[TICKET_UPDATE=PUBLIC]"
        $LargeDiskOutput += "[TICKET_STATUS=REQUIRE FEEDBACK]"
        $LargeDiskOutput += "[TICKET_PAAS_REMEDIATION=TRUE]"
        $LargeDiskOutput += "[TICKET_PAAS_DEVICE=$($ResourceId)]"
        $LargeDiskOutput += "Hello Team,`n`nSupport for >1TB disk VMs, and improvements for backup and restore speed is now available:"
        $LargeDiskOutput += "`n`nMicrosoft Article:`n----------------------------------------------------------------------------------`n"
        $LargeDiskOutput += "https://docs.microsoft.com/en-gb/azure/backup/backup-upgrade-to-vm-backup-stack-v2"
        $LargeDiskOutput += "`n----------------------------------------------------------------------------------`n`n"
        $LargeDiskOutput += "Guest OS Information:`n----------------------------------------------------------------------------------"
        $LargeDiskOutput += "`nVirtual Machine  : $($ComputerName)"
        $LargeDiskOutput += "`nOperating System : $($OSType)"
        $LargeDiskOutput += "`nIPv4 Address     : $($LocalIpAddress)"
        $LargeDiskOutput += "`nLast Reboot Time : $($LastReboot.DateTime)"
        $LargeDiskOutput += "`n----------------------------------------------------------------------------------"
        $LargeDiskOutput += "`n`nPlease let us know if you want to leverage backup stack v2?`n`n"
        $LargeDiskOutput += "$($ticketSignature)"
        #endregion

        $LargeDiskOutput
        #loopcheck
    }
    #Agent Not responsive output
    elseif ($FailureDetails -like "*Unable to perform the operation as the VM agent is not responsive*" -or $FailureDetails -like "*Please make sure that latest virtual machine agent is present*" -or $FailureDetails -like "*Please retry the backup operation*")
    {
        #Update VM Agent version
        $WinAzureGuestAgentInstall = Install-WinAzureGuestAgent

        #perform service restart
        $rsvService1 = Restart-rsAzureService -ServiceName WindowsAzureGuestAgent
        $rsvService2 = Restart-rsAzureService -ServiceName IaasVmProvider
        $rsvService3 = Restart-rsAzureService -ServiceName VSS

        #region VMAgentNotResponsiveOutput
        $VMAgentNotResponsiveOutput = $null
        $VMAgentNotResponsiveOutput += "Hello Team,`n`nThis error is thrown if there is a problem with the VM Agent or network access to the Azure infrastructure is blocked in some way. Automated remediation has attempted to update the Windows Azure Guest Agent and restart each Azure-related Backup service, as well as, set its start-up type to 'Automatic':"
        $VMAgentNotResponsiveOutput += "`n`nGuest OS Information:`n------------------------------------------------------------"
        $VMAgentNotResponsiveOutput += "`nVirtual Machine  : $($ComputerName)"
        $VMAgentNotResponsiveOutput += "`nOperating System : $($OSType)"
        $VMAgentNotResponsiveOutput += "`nIPv4 Address     : $($LocalIpAddress)"
        $VMAgentNotResponsiveOutput += "`nLast Reboot Time : $($LastReboot.DateTime)"
        $VMAgentNotResponsiveOutput += "`n------------------------------------------------------------"
        $VMAgentNotResponsiveOutput += "`n`nWindows Azure Guest Agent Update:`n------------------------------------------------------------------------------------------------`n"
        $VMAgentNotResponsiveOutput += "$($WinAzureGuestAgentInstall)"
        $VMAgentNotResponsiveOutput += "`n------------------------------------------------------------------------------------------------"
        $VMAgentNotResponsiveOutput += "`n`nAzure Backup Services Report:`n------------------------------------------------------------------------------------------------`n"
        $VMAgentNotResponsiveOutput += "$($rsvService1)`n`n"
        $VMAgentNotResponsiveOutput += "$($rsvService2)`n`n"
        $VMAgentNotResponsiveOutput += "$($rsvService3)"
        $VMAgentNotResponsiveOutput += "`n------------------------------------------------------------------------------------------------`n`n"
        #Confirm Agent installation success and kick off PaaS remediation
        if (($WinAzureGuestAgentInstall).Contains("successfully"))
        {
            $VMAgentNotResponsiveOutput += "Guest OS remediation complete. Azure platform remediation initiated, another update will follow shortly.`n`n"
            $VMAgentNotResponsiveOutput += "$($ticketSignature)"
            $VMAgentNotResponsiveOutput += "[TICKET_UPDATE=PUBLIC]"
            $VMAgentNotResponsiveOutput += "[TICKET_STATUS=ALERT RECEIVED]"
            $VMAgentNotResponsiveOutput += "[TICKET_PAAS_REMEDIATION=TRUE]"
            $VMAgentNotResponsiveOutput += "[TICKET_PAAS_DEVICE=$($ResourceId)]"
        }
        #Agent install failure, do not kick off paas remediation
        else
        {
            $VMAgentNotResponsiveOutput += "Windows Azure Guest Agent update failed, please remediate manually. Logs can be found in directory: C:\rs-pkgs\VmAgentInstaller\`n`n"
            $VMAgentNotResponsiveOutput += "$($ticketSignature)"
            $VMAgentNotResponsiveOutput += "[TICKET_UPDATE=PRIVATE]"
            $VMAgentNotResponsiveOutput += "[TICKET_STATUS=ALERT RECEIVED]"
        }
        #endregion

        #Output
        $VMAgentNotResponsiveOutput
    }
    #COM+ Error Output
    elseif ($FailureDetails -like "*COM+*")
    {
        #perform service restart
        $COMService1 = Restart-rsAzureService -ServiceName COMSysApp
        
        #region COM+ Output
        $COMOutput = $null
        $COMOutput += "[TICKET_UPDATE=PUBLIC]"
        $COMOutput += "[TICKET_STATUS=ALERT RECEIVED]"
        $COMOutput += "[TICKET_PAAS_REMEDIATION=TRUE]"
        $COMOutput += "[TICKET_PAAS_DEVICE=$($ResourceId)]`n"
        $COMOutput += "Hello Team,`n`nAutomated remediation has restarted Windows Service 'COM+ System Application':"
        $COMOutput += "`n`nGuest OS Information:`n------------------------------------------------------------"
        $COMOutput += "`nVirtual Machine  : $($ComputerName)"
        $COMOutput += "`nOperating System : $($OSType)"
        $COMOutput += "`nIPv4 Address     : $($LocalIpAddress)"
        $COMOutput += "`nLast Reboot Time : $($LastReboot.DateTime)"
        $COMOutput += "`n------------------------------------------------------------"
        $COMOutput += "`n`nWindows Services Report:`n------------------------------------------------------------`n"
        $COMOutput += "$($COMService1)"
        $COMOutput += "`n------------------------------------------------------------`n`n"
        $COMOutput += "Guest OS remediation complete. An ad-hoc backup job will be initiated shortly and the results posted to this ticket.`n`n"
        $COMOutput += "$($ticketSignature)"
        #endregion

        #Output
        $COMOutput
    }
    else
    {
        #perform service restart
        $rsvService1 = Restart-rsAzureService -ServiceName WindowsAzureGuestAgent
        $rsvService2 = Restart-rsAzureService -ServiceName IaasVmProvider
        $rsvService3 = Restart-rsAzureService -ServiceName VSS

        $CatchOutput = $null
        $CatchOutput += "[TICKET_UPDATE=PRIVATE]"
        $CatchOutput += "[TICKET_STATUS=ALERT RECEIVED]"
        $CatchOutput += "[TICKET_PAAS_REMEDIATION=TRUE]"
        $CatchOutput += "[TICKET_PAAS_DEVICE=$($ResourceId)]`n"
        $CatchOutput += "Unrecognised FailureDetails property. Please review the following Smart Ticket Scripts wiki for what is recognised:`n`n"
        $CatchOutput += "https://one.rackspace.com/pages/viewpage.action?title=Smart+Tickets+Scripts&spaceKey=FSFA#SmartTicketsScripts-raxbackupvaulterror.ps1"
        $CatchOutput += "`n`nGuest OS Information:`n-------------------------------------------------------------------"
        $CatchOutput += "`nVirtual Machine  : $($ComputerName)"
        $CatchOutput += "`nOperating System : $($OSType)"
        $CatchOutput += "`nIPv4 Address     : $($LocalIpAddress)"
        $CatchOutput += "`nLast Reboot Time : $($LastReboot.DateTime)"
        $CatchOutput += "`n-------------------------------------------------------------------"
        $CatchOutput += "`n`nAzure Backup Services Report:`n-------------------------------------------------------------------`n"
        $CatchOutput += "$($rsvService1)`n`n"
        $CatchOutput += "$($rsvService2)`n`n"
        $CatchOutput += "$($rsvService3)"
        $CatchOutput += "`n-------------------------------------------------------------------`n`n"
        $CatchOutput += "Please troubleshoot manually.`n`n"
        $CatchOutput += "$($ticketSignature)"

        #Output
        $CatchOutput
    }
    #endregion
}
catch
{
    $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
    Write-Output $ErrMsg 
}