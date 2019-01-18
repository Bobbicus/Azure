 <#
    .SYNOPSIS
    Initiate a Recovery Service Vault Backup job.
       
    .DESCRIPTION
    Initiate an Azure Recovery Services Vault Backup job for a given VM..

    Supported: Yes
    Keywords: azure,recovery,service,vault,backup,smarttickets
    Prerequisites: No
    Makes changes: Yes

    .EXAMPLE
    Full command:  .\raxbackupvaulterror.paas.ps1
    Description: Initiates a backup job and outputs on success or failure.
       
    .OUTPUTS
    Example output:
 
    Hello Team,

    Smart Ticket Automation has automatically initiated a new backup job for VM - OH-DC-1:

    Backup Job Status (Before remediation):
    ------------------------------------------------------------
    VM Workload   : OH-DC-1
    Power State   : VM running
    Vault         : oliv8274-rsv
    ResourceGroup : oliv8274-drad1
    Subscription  : e44872b2-e898-46d0-800f-59752a564718
    Status        : Failed
    Start Time    : 04/10/2018 11:24:16
    End Time      : 04/10/2018 11:24:17
    Backup Job Id : 24cd69a6-9592-47fa-84bd-48eff33bae4c
    ------------------------------------------------------------

    Backup Job Status (After remediation):
    ------------------------------------------------------------
    VM Workload   : OH-DC-1
    Power State   : VM running
    Vault         : oliv8274-rsv
    ResourceGroup : oliv8274-drad1
    Subscription  : e44872b2-e898-46d0-800f-59752a564718
    Status        : InProgress
    Start Time    : 04/11/2018 10:22:46
    End Time      : 
    Backup Job Id : 7cfd259e-43fb-4cc4-91a9-115251ec9178
    ------------------------------------------------------------

    Remediation is complete. Please feel free to update this ticket if you have any questions.

    Kind regards,

    Smart Ticket Automation.
    Rackspace Toll Free: (800) 961-4454

        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0

    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Oliver Hurn        :: 07-JUN-2018 :: XX-XXX   :: Bob Larkin  :: Release
    1.1     :: Oliver Hurn        :: 14-JUN-2018 :: XX-XXX   :: Chris Clark :: Minor Fix #line 377
#>

    #region Payload
    #Script Uri
    Param(
    [Parameter(Mandatory=$true)]$PayloadUri
    )
    #>

    #Testing payload
    #$object = ConvertFrom-Json "$(get-content -Path C:\Users\oliv8274\Desktop\payload\rsv.json)"
    #$object = ConvertFrom-Json "$(get-content -Path C:\Users\oliv8274\Desktop\payload\nsg.json)"
    #$object = ConvertFrom-Json "$(get-content -Path C:\Users\oliv8274\Desktop\payload\vmstate.json)"

try
{    
    
        #Ingest the payload (Production)
        $object = Invoke-RestMethod -Uri $PayloadUri

        #Set Payload variables
        $Workload = $object.Computer
        $FailureDetails = $object.Properties.FailureDetails
        $JobId = $object.Properties.'Job Id'
        $Subscription = $object.SubscriptionId
        $ResourceGroup = $object.ResourceGroup
        $ResourceId = $object.ResourceId
        $RsvName = $object.ResourceId | Split-Path -Leaf
        #endregion
        
        $ticketSignature = "Kind regards,`n`nSmart Ticket Automation`nRackspace Toll Free (US): 1800 961 4454`n                    (UK): 0800 032 1667"

    #Function to check recent failed backup jobs and stop the REQUIRE FEEDBACK loop through blind auto-remediation. 
    #$Amount is the number of failed jobs to stop the loop at.
    Function Get-LoopCheck
    {
        Param(
        [Parameter(Mandatory=$true)][int]$Amount
        )
        try
        {                        
            #Set Rsv Context
            Get-AzureRmRecoveryServicesVault -Name $RsvName | Set-AzureRmRecoveryServicesVaultContext

            #Collect all failed Backup jobs for $Workload (Range: 3 days, First 2 records)
            $FailedJobs = Get-AzureRmRecoveryServicesBackupJob -From (Get-Date).AddDays(-($Amount+1)).ToUniversalTime() -Status Failed | Where-Object {$_.WorkloadName -eq $Workload} 

            #If the last two jobs have failed, Racker intevention is required.
            if ($FailedJobs.Count -ge $Amount)
            {
                #Build validation Output
                $OutputStop = $null
                $OutputStop += "[TICKET_UPDATE=PRIVATE]`n"
                $OutputStop += "[TICKET_STATUS=ALERT RECEIVED]`n"
                $OutputStop += "------------------------------`n"
                $OutputStop += "Smart Ticket Validation Check:`n"
                $OutputStop += "------------------------------`n"
                $OutputStop += "$($Amount) or more failed backup jobs found for Workload: $($Workload) in the last $($Amount+1) days. Racker investigation required.`n`n"
                $OutputStop += "$($FailedJobs | Select-Object -First $Amount | Format-Table -AutoSize | Out-String)"                
                
                #Output
                $OutputStop
            }
            #If only the last job has failed or less, attempt automated remediation
            elseif ($FailedJobs.Count -le ($Amount-1))
            {
                #Build validation Output
                $OutputContinue = $null
                $OutputContinue += "[TICKET_UPDATE=PRIVATE]`n"
                $OutputContinue += "[TICKET_STATUS=REQUIRE FEEDBACK]`n"
                $OutputContinue += "------------------------------`n"
                $OutputContinue += "Smart Ticket Validation Check:`n"
                $OutputContinue += "------------------------------`n"
                $OutputContinue += "$($Amount-1) or less failed backup jobs found for Workload: $($Workload) in the last $($Amount+1) days. No manual troubleshooting required.`n`n"
                $OutputContinue += "$($FailedJobs | Select-Object -First $Amount | Format-Table -AutoSize | Out-String)"                
                
                #Output
                $OutputContinue
            }
        }
        catch
        {
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
            Write-Output $ErrMsg 
        }
    }

    #Function to get VM State
    Function Get-VmState
    {
        try
        {
            #Create VM variable
            $vm = Get-AzureRmVM -Status | Where-Object {$_.Name -like "*$Workload*"}

            #Get the PowerState of the VM
            $powerState = $vm.PowerState
        }
        catch
        {
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
            Write-Output $ErrMsg 
        }
        return $powerState
    }
        #Set $powerState variable
        $powerState = Get-VmState

    #Function to get VM State
    Function Get-VmStateAndExt
    {
        try
        {
            #Create VM variable
            $vm = Get-AzureRmVM -Status | Where-Object {$_.Name -like "*$Workload*"}

            #Get the PowerState of the VM
            $powerState = $vm.PowerState

            #Get Failed Extensions
            $FailedExt = $vm.Extensions.Statuses | Where-Object {$_.Level -eq 'Error'} 

            if ($FailedExt -ne $null)
            {
                $FailedExt = $FailedExt | Select DisplayStatus, Message | Out-String
            }
            else
            {
                $FailedExt = "No failed extensions found.`n`n"
            }
        
            if ($powerState -eq "VM running")
            {
                $ExtOutput = $null
                $ExtOutput += "[TICKET_UPDATE=PUBLIC]`n"
                $ExtOutput += "[TICKET_STATUS=ALERT RECEIVED]`n"
                $ExtOutput += "Hello Team,`n`nSmart Ticket Automation has confirmed the PowerState of VM - $($Workload) and retrieved any installed extensions in a failed state:`n"
                $ExtOutput += "`n`Virtual Machine Details:`n------------------------------------------------------------`n"
                $ExtOutput += "VM Workload       : $($Workload)`n"
                $ExtOutput += "Power State       : $($powerState)`n"
                $ExtOutput += "Resource Group    : $($vm.ResourceGroupName)`n"
                $ExtOutput += "VM Agent Version  : $($vm.VMAgent.VmAgentVersion)`n`n"
                $ExtOutput += "Failed Extensions :`n"
                $ExtOutput += "------------------------------------------------------------`n"
                $ExtOutput += "$FailedExt"
                $ExtOutput += "A Racker will review the Failed Extensions report and delete the necessary extension to resolve the VM's Failed PowerState. If this doesn't resolve the issue, a reboot may be required.`n`n"
                $ExtOutput += "$($ticketSignature)"
            }
            else
            {
                $ExtOutput = $null
                $ExtOutput += "[TICKET_UPDATE=PUBLIC]`n"
                $ExtOutput += "[TICKET_STATUS=ALERT RECEIVED]`n"
                $ExtOutput += "Hello Team,`n`nSmart Ticket Automation has confirmed the PowerState of VM- $($Workload) to be: $($powerState), therefore, please troubleshoot manually."
                $ExtOutput += "`n`nVirtual Machine Details:`n------------------------------------------------------------`n"
                $ExtOutput += "VM Workload       : $($Workload)`n"
                $ExtOutput += "Power State       : $($powerState)`n"
                $ExtOutput += "Resource Group    : $($vm.ResourceGroupName)`n"
                $ExtOutput += "VM Agent Version  : $($vm.VMAgent.VmAgentVersion)`n`n"
                $ExtOutput += "$($ticketSignature)"       
            }
        }
        catch
        {
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
            Write-Output $ErrMsg 
        }
        return $ExtOutput
    }

    #Function to get VM State
    Function Get-OutboundNsg
    {
        try
        {
            #Get VM object
            $vm = Get-AzureRmVM | Where-Object {$_.Name -like "*$Workload*"}

            #Retrieve the Nic Name
            $nic = $vm.NetworkProfile.NetworkInterfaces.id | Split-Path -Leaf
            
            #Retrieve the effective NSGs for the given Nic
            $nsg = Get-AzureRmEffectiveNetworkSecurityGroup -NetworkInterfaceName $nic -ResourceGroupName $vm.ResourceGroupName

            #Get NSG Name
            $NsgName = $nsg.NetworkSecurityGroup.Id | Split-Path -Leaf

            #Get Subnet Name
            $subnet = $nsg.Association.Subnet.Id | Split-Path -Leaf -ErrorAction SilentlyContinue
            if ($subnet -eq $null)
            {
                $subnet = "No rule at subnet level."
            }

            #Filter out Default Rules and only Outbound rules first
            $OutBoundNsg = $nsg.EffectiveSecurityRules | Where-Object {$_.Name -notlike "defaultSecurityRules*" -and $_.Direction -eq 'Outbound'} 

            #Then filter by HTTPS/TCP443 rules
            $OutBoundNsg443 = $OutBoundNsg | Where-Object {$_.DestinationPortRange -like "*443*"} 
            
            #Then filter by Deny rules
            $OutBoundNsgDeny = $OutBoundNsg | Where-Object {$_.Access -eq "Deny"} 

            #If Outbound Rules are present, print output.
            if ($OutBoundNsg -ne $null)
            {
                $NSGOutput = $null
                $NSGOutput += "[TICKET_UPDATE=PUBLIC]`n"
                $NSGOutput += "[TICKET_STATUS=ALERT RECEIVED]`n"
                $NSGOutput += "Hello Team,`n`nSmart Ticket automation has successfully retrieved the associated Outbound Network Security Group (NSG) rules:`n`n"
                $NSGOutput += "Network Security Group Information:`n------------------------------------------"
                $NSGOutput += "`nVirtual Machine   : $($Workload)"
                $NSGOutput += "`nResource Group    : $($vm.ResourceGroupName)"
                $NSGOutput += "`nAssociated Subnet : $($subnet)"
                $NSGOutput += "`nOutbound NSG      : $($NsgName)"
                $NSGOutput += "`n------------------------------------------`n`n"
                $NSGOutput += "Outbound NSG rules: Allow - HTTPS:`n"
                $NSGOutput += "------------------------------------------`n"
                if ($OutBoundNsg443 -ne $null)
                {
                    $NSGOutput += "$($OutBoundNsg443 | Sort-Object Priority | Select-Object Name, Priority, Protocol, SourcePortRange, DestinationPortRange, SourceAddressPrefix, DestinationAddressPrefix, Access -First 5 | Format-Table | Out-String)"
                }
                else 
                {
                    $NSGOutput += "No HTTPS rules found.`n`n"
                }
                $NSGOutput += "Outbound NSG rules: Deny - Any:`n"
                $NSGOutput += "------------------------------------------`n"
                if ($OutBoundNsgDeny -ne $null)
                {
                    $NSGOutput += "$($OutBoundNsgDeny | Sort-Object Priority | Select-Object Name, Priority, Protocol, SourcePortRange, DestinationPortRange, SourceAddressPrefix, DestinationAddressPrefix, Access -First 5 | Format-Table | Out-String)"
                }
                else
                {
                    $NSGOutput += "No DENY rules found.`n`n"
                }
                $NSGOutput += "Review the rules (limited to -First 5)  and determine if Azure Datacenter ranges are accessible over HTTPS.`n`n"
                $NSGOutput += "$($ticketSignature)"   
            }
            #If no Outbound rules can be found, print output.
            elseif ($OutBoundNsg -eq $null)
            {
                $NSGOutput = $null
                $NSGOutput += "[TICKET_UPDATE=PUBLIC]`n"
                $NSGOutput += "[TICKET_STATUS=ALERT RECEIVED]`n"
                $NSGOutput += "Hello,`n`nSmart Ticket automation did not find any Outbound Security Rules configured:`n`n"
                $NSGOutput += "Network Security Group Information:`n-----------------------------------------"
                $NSGOutput += "`nVirtual Machine   : $($Workload)"
                $NSGOutput += "`nResource Group    : $($vm.ResourceGroupName)"
                $NSGOutput += "`nAssociated Subnet : $($subnet)"
                $NSGOutput += "`nOutbound NSG      : $($NsgName)"
                $NSGOutput += "`n-----------------------------------------`n`n"
                $NSGOutput += "An Azure engineer will continue to troubleshoot manually.`n`n"
                $NSGOutput += "$($ticketSignature)"
            }
            #Error Output
            else
            {
                $NSGOutput += "[TICKET_UPDATE=PRIVATE]`n"
                $NSGOutput += "[TICKET_STATUS=ALERT RECEIVED]`n"
                $NSGOutput += "Smart Ticket Automation encountered an error."
            }
        }
        catch
        {
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
            Write-Output $ErrMsg 
        }
        return $NSGOutput
    }

    #Function to initiate ad-hoc backup job
    Function Run-RsvBackup
    {
        try
        {
            #region Script Commands
            #Amount of failed jobs to prevent looping. i.e. if 2 failed jobs are found in the last 3 days, automation will stop.
            $Amount = 3

            #Set Rsv Context
            Get-AzureRmRecoveryServicesVault -Name $RsvName | Set-AzureRmRecoveryServicesVaultContext

            #Collect original backup job details
            $BackupJob = Get-AzureRmRecoveryservicesBackupJob -From (Get-Date).AddDays(-5).ToUniversalTime() -Status Failed -JobId $JobId

            #Collect all failed Backup jobs for $Workload (Range: 3 days, First 2 records)
            $FailedJobs = Get-AzureRmRecoveryServicesBackupJob -From (Get-Date).AddDays(-($Amount+1)).ToUniversalTime() -Status Failed | Where-Object {$_.WorkloadName -eq $Workload} 

            #If the last two jobs have failed, Racker intevention is required.
            if ($FailedJobs.Count -ge $Amount)
            {
                #Build validation Output
                $Output0 = $null
                $Output0 += "[TICKET_UPDATE=PRIVATE]"
                $Output0 += "[TICKET_STATUS=ALERT RECEIVED]`n"
                $Output0 += "-----------------------------`n"
                $Output0 += "Smart Ticket Validation: FAIL`n"
                $Output0 += "-----------------------------`n"
                $Output0 += "$($Amount) or more failed backup jobs found for Workload: $($Workload) in the last $($Amount+1) days. Racker investigation required.`n`n"
                $Output0 += "$($FailedJobs | Format-Table -AutoSize | Out-String)"                
                
                #Output
                $Output0
            }
            #If only the last job has failed or less, attempt automated remediation
            elseif ($FailedJobs.Count -le ($Amount-1))
            {

                #Get VM object to gaurantee VM Name case matches upper or lower
                $vmName = (Get-AzureRmVM | Where-Object {$_.Name -like "*$Workload*"}).Name

                #Collect Protection and Policy information for specified VM
                $container = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -FriendlyName $vmName -ErrorAction SilentlyContinue
                $Detail =  Get-AzureRmRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM -ErrorAction SilentlyContinue

                If ($object.activityStatus -eq 'Failed')
                {
                    #Initiate new Backup job
                    $itemVM = Get-AzureRmRecoveryServicesBackupItem -BackupManagementType AzureVM -Name $Workload -WorkloadType AzureVM
                    $backupVM = Backup-AzureRmRecoveryServicesBackupItem -Item $itemVM -ErrorAction SilentlyContinue
                }
                #endregion
       
                #region Ticket Logic
                #Ticket update Logic
                if ($backupVM.Status -eq 'InProgress')
                {
                    #Output variable for a successful update. Action publicly updates ticket, confirms webjob status is Success
                    $Output1 = $null
                    $Output1 += "[TICKET_UPDATE=PUBLIC]"
                    $Output1 += "[TICKET_STATUS=CONFIRM SOLVED]`n"
                    $Output1 += "Hello Team,`n`nSmart Ticket Automation has automatically initiated a new backup job for VM - $($Workload):`n"
                    $Output1 += "`n`Backup Job Status (Before remediation):`n--------------------------------------------------------`n"
                    $Output1 += "VM Workload   : $($Workload)`n"
                    $Output1 += "Power State   : $($powerState)`n"
                    $Output1 += "Vault         : $($RsvName)`n"
                    $Output1 += "ResourceGroup : $($ResourceGroup)`n"
                    $Output1 += "Subscription  : $($Subscription)`n"
                    $Output1 += "Status        : $($BackupJob.Status)`n"
                    $Output1 += "Start Time    : $($BackupJob.StartTime)`n"
                    $Output1 += "End Time      : $($BackupJob.EndTime)`n"
                    $Output1 += "Backup Job Id : $($BackupJob.JobId)"
                    $Output1 += "`n--------------------------------------------------------`n"
                    $Output1 += "`n`Backup Job Status (After remediation):`n--------------------------------------------------------`n"
                    $Output1 += "VM Workload   : $($Workload)`n"
                    $Output1 += "Power State   : $($powerState)`n"
                    $Output1 += "Vault         : $($RsvName)`n"
                    $Output1 += "ResourceGroup : $($ResourceGroup)`n"
                    $Output1 += "Subscription  : $($Subscription)`n"
                    $Output1 += "Status        : $($backupVM.Status)`n"
                    $Output1 += "Start Time    : $($backupVM.StartTime)`n"
                    $Output1 += "End Time      : $($backupVM.EndTime)`n"
                    $Output1 += "Backup Job Id : $($backupVM.JobId)"
                    $Output1 += "`n--------------------------------------------------------`n`n"
                    $Output1 += "Remediation is complete. We will continue to monitor for any future alerts and investigate further if there are any issues. Please feel free to update this ticket if you have any questions.`n`n"
                    $Output1 += "$($ticketSignature)"
                                    
                    #Successful Output
                    $Output1
                }
                elseif ($backupVM.Status -eq 'Failed')
                {
                    #Privately updates ticket and with backup job failed state
                    $Output2 = $null
                    $Output2 += "[TICKET_UPDATE=PUBLIC]"
                    $Output2 += "[TICKET_STATUS=ALERT RECEIVED]`n"
                    $Output2 += "Hello,`n`nSmart Ticket Automation attempted to automatically initiate a new backup job for VM - $($Workload):`n"
                    $Output2 += "`n`Protection Details:`n--------------------------------------------------------`n"
                    $Output2 += "VM Workload      : $($Workload)`n"
                    $Output2 += "Power State      : $($powerState)`n"
                    $Output2 += "RecoveryVault    : $($RsvName)`n"
                    $Output2 += "ResourceGroup    : $($ResourceGroup)`n"
                    $Output2 += "Subscription     : $($Subscription)`n"
                    $Output2 += "PolicyName       : $($Detail.ProtectionPolicyName)`n"
                    $Output2 += "ProtectionStatus : $($Detail.ProtectionStatus)`n"
                    $Output2 += "ProtectionState  : $($Detail.ProtectionState)`n"
                    $Output2 += "LastBackupStatus : $($Detail.LastBackupStatus)`n"
                    $Output2 += "LastBackupTime   : $($Detail.LastBackupTime)`n"
                    $Output2 += "--------------------------------------------------------`n`n"
                    $Output2 += "Backup Retry Job Details:`n"
                    $Output2 += "--------------------------------------------------------`n"
                    $Output2 += "Status           : $($backupVM.Status)`n"
                    $Output2 += "Start Time       : $($backupVM.StartTime)`n"
                    $Output2 += "End Time         : $($backupVM.EndTime)`n"
                    $Output2 += "Backup Job Id    : $($backupVM.JobId)`n"
                    $Output2 += "Error Message    : $($backupVM.ErrorDetails.ErrorMessage)`n"
                    $Output2 += "Recommendation   : $($backupVM.ErrorDetails.Recommendations)"
                    $Output2 += "`n--------------------------------------------------------`n`n"
                    $Output2 += "A Racker will investigate further as the Backup Job failed its retry attempt. Review the above Error Message for more details.`n`n"
                    $Output2 += "$($ticketSignature)"
                 
                    #Failure Output
                    $Output2
                }
                else
                {
                    
                    #Error Output if status can't be returned
                    $Output3 = $null
                    $Output3 += "[TICKET_UPDATE=PRIVATE]"
                    $Output3 += "[TICKET_STATUS=ALERT RECEIVED]`n"
                    $Output3 += "Smart Ticket Automation couldn't determine Backup Job status for VM: $($Workload). Potentially, backups are disabled, please troubleshoot manually."    
                                    
                    #Error Output
                    $Output3
                }
                #endregion
            }
        }
        catch
        {
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
            Write-Output $ErrMsg 
        }
    }

        #region Decision logic and Ticket Output Section

        #VMAgent Error
        if ($FailureDetails -like "*VM agent is unable to communicate with the Azure Backup Service.  Ensure the VM has network connectivity and the VM agent is latest and running.*" -or $FailureDetails -like "*Could not communicate with the VM agent for snapshot status*" -or $FailureDetails -like "*Please retry the backup operation*")
        {
            #Initiate ad-hoc backup job
            Run-RsvBackup
        }
        #VSS Writer Error
        elseif ($FailureDetails -like "*Snapshot operation failed due to VSS*")
        {
            #Initiate ad-hoc backup job
            Run-RsvBackup
        }
        #NSG Whitelist Error
        elseif ($FailureDetails -like "*For snapshot to succeed, either whitelist Azure datacenter IP ranges*")
        {
            #Collect Outbound Nsg rules
            Get-OutboundNsg
        }
        #VM Failed State Error
        elseif ($FailureDetails -like "*VM is in Failed Provisioning State*")
        {
            #Check PowerState and Failed Extensions
            Get-VmStateAndExt
        }
        #Large Disk Error
        elseif ($FailureDetails -like "*The specified Disk Configuration is not supported*" -or $FailureDetails -like "*Azure Backup does not support disk sizes greater than 1023GB*")
        {
            #Loop will stop if $amount failed jobs is found. $amount or less it will continue
            Get-LoopCheck -Amount 3
        }
        #Agent Not responsive output
        elseif ($FailureDetails -like "*Unable to perform the operation as the VM agent is not responsive*" -or $FailureDetails -like "*Please make sure that latest virtual machine agent is present*")
        {
            #Initiate ad-hoc backup job
            Run-RsvBackup
        }
        #COM+ Error Output
        elseif ($FailureDetails -like "*COM+*")
        {
            #Initiate ad-hoc backup job
            Run-RsvBackup
        }
        else
        {
            Get-AzureRmRecoveryServicesVault -Name $RsvName | Set-AzureRmRecoveryServicesVaultContext
            $FailedJobs = Get-AzureRmRecoveryServicesBackupJob -From (Get-Date).AddDays(-3).ToUniversalTime() -Status Failed | Where-Object {$_.WorkloadName -eq $Workload}

            #Catch all Output
            $CatchOutput = $null
            $CatchOutput += "[TICKET_UPDATE=PRIVATE]"
            $CatchOutput += "[TICKET_STATUS=ALERT RECEIVED]`n"
            $CatchOutput += "Unrecognised PaaS FailureDetails property. Please review the following Smart Ticket Script wiki for what is recognised:`n`n"
            $CatchOutput += "https://one.rackspace.com/pages/viewpage.action?title=Smart+Tickets+Scripts&spaceKey=FSFA#SmartTicketsScripts-raxbackupvaulterror.ps1`n`n"
            $CatchOutput += "-------------------------`n"
            $CatchOutput += "Failed Backup Job Report:`n"
            $CatchOutput += "-------------------------`n"
            $CatchOutput += "$($FailedJobs | Select-Object -First 5 | Format-Table -AutoSize | Out-String)"

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