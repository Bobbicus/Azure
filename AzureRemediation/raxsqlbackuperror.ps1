<#
    .SYNOPSIS
    Checks if the SQL backup completed on second attempt.  
       
    .DESCRIPTION
    Full description: Script filters database name from alert payload. Checks database name against successful back which occurred after time stamp of backup failure. AutoRemediation is set to true which will add registy key.
    supported: Yes
    Prerequisites: Yes/No
    Makes changes: Yes

    .EXAMPLE
    Full command: Function Get-DatabaseNamePayload, Get-DatabaseNameEventviewer, Set-CompareDbNames 
    Description: Compares payload database name to event entries with successful backup in the last 5 minutes.
    Output: Return data depends on check, if successful update ticket and close. If not private need further investigation

       
    .OUTPUTS
    Check output
        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    3.3     :: Chris Clark        :: 27-March-2018 :: MPA-20 ::Oliver Hurn  :: SQL backup Check
#>

param(
    [string]$PayLoadUrl
    )


$AutoRemediation = $False
$DbNamesPayload = @()
$EvntDbNames = @()

function Get-DatabaseNamePayload {
try {
<#
    .SYNOPSIS
    The funtion takes extracts the database names from the JSON payload as well as the oldes time stamp. 
       
    .DESCRIPTION
    Full description: Function extracts databases names and oldest time stamp from JSON backup to use with the Compare-DbNames function. 
      
#>
    $jsonpayload = Invoke-RestMethod -Uri $PayLoadUrl
    #test
    #$jsonpayload = Invoke-RestMethod -Uri "https://raxsmarttickets.blob.core.windows.net/alert-payload-dev/samples/raxsqlbackuperror_payload_2Db.json?sv=2017-04-17&si=alert-payload-dev-15EA2944062&sr=c&sig=%2BrzZX7BaOpzeKQYQRhbVz%2F4ZG7lyZMB3dSDbkFGFSfE%3D"
    #end test
    $regexDbnamePayload = [regex]'(?<=\bDATABASE \b).*?(?=\.)'#pull db name after DATABASE payload error Only
    $regexLognamePayload = [regex]'(?<=\bLOG ).*?(?=\.)'#pull db name after LOG Payload error Only
    [datetime]$Global:timeGenall =$jsonpayload.TimeGenerated | Select-Object -Last 1

    if($jsonpayload -eq $null){
        return $null}
        else{
            foreach ($jsonload in $jsonpayload){
                if ($jsonload.RenderedDescription -clike "*LOG*"){
                        [array]$DbNamesPayload += $regexLognamePayload.Matches($jsonload.RenderedDescription).value}
                    else{
                        [array]$DbNamesPayload += $regexDbnamePayload.Matches($jsonload.RenderedDescription).value}
            }
        }
    return ($DbNamesPayload | Select-Object -Unique)
}
catch {
        #Information to be added to private comment in ticket when unknown error occurs
        $ScriptDbPayloadErr = $null
        $ScriptDbPayloadErr += Write-Output "Script failed to run`n"
        $ScriptDbPayloadErr += Write-Output = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
        return $ScriptDbPayloadErr
    }
}

function Get-DatabaseNameEventviewer {
try {
<#
    .SYNOPSIS
    The funtion takes the time stamp from JSON pay load and retrieves all successfull backup database names after the time stamp. Returns unique database names.
       
    .DESCRIPTION
    Full description: Function extracts database names from successful backup from event viewer after time stamp from Get-DbNamePayload. Returns values for Compare-DnNames
      
#>
    $regexDbnameEvent = [regex]'(?is)(?<=\bDATABASE: \b).*?(?=\,)'#pull db name after DATABASE Evenet viewer for both LOG/DATABASE backup
    $dbeventlogs = Get-EventLog application -after $Global:timeGenall -EntryType Information | Where-Object {($_.EventID -eq '18264') -or ($_.EventID -eq '18265')}
    
    if($dbeventlogs -eq $Null){ #check if event viewer returned data based on time frame
        return $Null}
        else{
            foreach($dbeventlog in $dbeventlogs ){
                    [array]$EvntDbNames += $regexDbnameEvent.Matches($dbeventlog.Message).value}
        }
    return ($EvntDbNames | Select-Object -Unique)
}
catch {
        #Information to be added to private comment in ticket when unknown error occurs
        $ScriptEventViewerErr = $null
        $ScriptEventViewerErr += Write-Output "Script failed to run`n"
        $ScriptEventViewerErr += Write-Output "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
        return $ScriptEventViewerErr
    }
}   
function Compare-DbNames {
<#
    .SYNOPSIS
    The funtion takes the vaules from both the Get-DatabaseNameEventviewer function and Get-DatabaseNamePayload to compare the databases names. If both array match then
    update and close ticket. If not private comment with the DB names that did not successfully backup on the next attempt. 
       
    .DESCRIPTION
    Full description: Script takes in two arrays and compares the values. If match confirm solve ticket, if not private update with DB names that was not successfull backed on next attempt.
      
#>
    param(
    [array]$DbNamesPayload,
    [array]$EvntDbNames,
    $AutoAutoRemediation
)
    try {
        #Check if payload data or event viewer data is returned as null
        if ($DbNamesPayload -eq $null -or $EvntDbNames -eq $null ){
            if ($EvntDbNames -ne $null){
                Write-Output "`n`n[TICKET_UPDATE=PRIVATE]"
                Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
                Write-Output "Could not filter out database name from alert payload"}
            else{
                Write-Output "`n`n[TICKET_UPDATE=PRIVATE]"
                Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
                Write-Output "There were no successful backups within the event viewer to compare. Please investigate database backup failure:"
                Write-Output "------------------------------------"
                Write-Output "Databases (Payload)"
                Write-Output "------------------------------------"
                Write-Output $DbNamesPayload
                Write-Output "------------------------------------"}
            }                
    else{
        if((Compare-Object -ReferenceObject ($EvntDbNames) -DifferenceObject ($DbNamesPayload) -PassThru | Where-Object {$EvntDbNames -NotContains $_}).count -eq 0){ #Test error by placing 1 in the count
            Write-Output "`n`n[TICKET_UPDATE=PUBLIC]"
            Write-Output "[TICKET_STATUS=CONFIRM SOLVED]"
            Write-Output "Hello Team,"
            Write-Output "`nUpon the first attempt, each database backup job failed due to a process potentially locking access to its underlying files. A second attempt was retried automatically, which completed successfully for all listed databases:`n"
            Write-Output "------------------------------------"
                foreach($dbnamePayload in $DbNamesPayload){Write-Output $dbnamePayload}
                    Write-Output "------------------------------------"
                    Write-Output "`nRackspace automation has confirmed this via Event Viewer records. Please feel free to update this ticket if you have any questions."
                    Write-Output "`nKind regards,"
                    Write-Output "`nMicrosoft Azure Engineer"
                    Write-Output "Rackspace Toll Free: (800) 961-4454"}
        else{
            [array]$DbsNotFound += Compare-Object -ReferenceObject ($EvntDbNames) -DifferenceObject ($DbNamesPayload) -PassThru | Where-Object {$EvntDbNames -NotContains $_}
            Write-Output "`n[TICKET_UPDATE=PRIVATE]"
            Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
            Write-Output "Smart Ticket remediation has cross-referenced the Database Name(s) in the JSON payload against successful backup record(s) found in the Event Viewer:`n" 
            Write-Output "------------------------------------"
            Write-Output "Databases (Payload)"
            Write-Output "------------------------------------"
            Write-Output $DbNamesPayload
            Write-Output "`n"
            Write-Output "------------------------------------"
            Write-Output "Databases (Event Viewer)"
            Write-Output "------------------------------------"
            Write-Output $EvntDbNames
            Write-Output "`n"
            Write-Output "------------------------------------"
            Write-Output "Databases (Missing)"
            Write-Output "------------------------------------"
            Write-Output $DbsNotFound
            Write-Output "`nPlease investigate the 'Missing' Database Backup failures and update the customer accordingly."
            <#Test
            Write-Output "Missing Database(s) not found between Payload and event viewer: $DbsNotFound"
            Write-Output "Database Names from Event Viewer: $EvntDbNames"
            Write-Output "Database Names from the Payload: $DbNamesPayload"
            Write-Output "Database time stamp: $Global:timeGenall`n"
            #End Test#>
            If ($AutoAutoRemediation -eq $True) {Write-Ouput "`nRegistry key was changed per article https://docs.microsoft.com/en-us/azure/backup/backup-azure-vms-troubleshoot USEVSSCOPYBACKUP = True"}
                    Else {Write-Output "`nThe following link has additional remediation steps https://docs.microsoft.com/en-us/azure/backup/backup-azure-vms-troubleshoot"}
            }
        }}
    catch {
                #Information to be added to private comment in ticket when unknown error occurs
                $ScriptDbCompareErr = $null
                $ScriptDbCompareErr += Write-Output "Script failed to run`n"
                $ScriptDbCompareErr += Write-Output "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                return $ScriptDbCompareErr
        }
   
}

function Get-VssRegKey {
<#
    .SYNOPSIS
    Performs a check if the VSS copy only registry key is configured, if not creates it.

    .DESCRIPTION
    The copy only for VSS writer should be enabled on SQL server to avoid deleting parsed logs. The check will return True if key is present. (https://docs.microsoft.com/en-us/azure/backup/backup-azure-vms-troubleshoot)

    .PARAMETER Value
    Path to the registry key and name of the registry Value

    .EXAMPLE
    Get-VssRegKey -Path 'HKLM:\SOFTWARE\Microsoft\BcdrAgent' -Value 'USEVSSCOPYBACKUP'

    .NOTES
    General notes
#>
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$RegVsspath,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$RegVssValue
    )

try {
    $VssRegChk = Get-ItemProperty -Path $RegVsspath | Select-Object -ExpandProperty $RegVssValue -ErrorAction SilentlyContinue
    If ($VssRegChk -ne $True){
        New-ItemProperty -Path $RegVsspath -Name $RegVssValue -Value 'TRUE' -PropertyType string -Force | Out-Null
        return $true}
    else {return $false}
    }
    catch {
        $ScriptVssRegChkErr = $null
        $ScriptVssRegChkErr += Write-Output "Script failed to run`n"
        $ScriptVssRegChkErr += Write-Output "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
        return $ScriptVssRegChkErr}
}

$RegVsspath = 'HKLM:\SOFTWARE\Microsoft\BcdrAgent'
$RegVssValue = 'USEVSSCOPYBACKUP'

If ($AutoRemediation -eq $True){
    $RegKeyValue = Get-VssRegKey $RegVsspath $RegVssValue
    }

$DbNamesPayload = Get-DatabaseNamePayload -PayLoadUrl $PayLoadUrl
$EvntDbNames = Get-DatabaseNameEventviewer
Compare-DbNames $DbNamesPayload $EvntDbNames $RegKeyValue