
<#
    .SYNOPSIS
    Cehck DNS state by checking for latest success and error events
       
    .DESCRIPTION
    Full description: Chack DNS state by checking for latest success and error events, restart DNS service if required
    supported: Yes
    keywords: DNS
    Prerequisites: Yes/No
    Makes changes: Yes
    Changes Made:
        Restarts DNS server service if required

    .EXAMPLE
    Full command: Get-DNSState
    Description: <description of what the command does>
    Output: <List output>
       
    .OUTPUTS
    <List outputs>
        
    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 4
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 20-Sep-2017 :: N/A      ::  :: Release
#>
Function Get-DNSState
{
    Try
    {
        function Get-DNSEvents
        {
            #Check for the last instance of event ID 4013, DNS error event.  Will either pull ID from the alert payload or include all DNS errors
            $LastErrorEvent = Get-WinEvent "DNS Server" | Where-Object {$_.ID -eq "4013"} | Select -First 1 
            $ErrorDate = $LastErrorEvent.TimeCreated

            #Check for last instance of Event ID 4 which show DNS is available
            $LastGoodEvent =Get-WinEvent "DNS Server" | Where-Object {$_.ID -eq "4"} | Select -First 1 
            $GoodDate = $LastGoodEvent.TimeCreated

            #Compare the error and good event to see if the good event is more recent
            $AlertState = (get-date $GoodDate) -gt (get-date $ErrorDate)
            return $AlertState

        }
        #Return DNS state True if event ID 4 is newer than the error event
        $DNSState = Get-DNSEvents

              
             if ($DNSState  -eq $true)
             {
                Write-Output "DNS State Good after service restart"
                Write-Output "Hello Team,`n`nWrite message here that will be posted to ticket."
                Write-Output "`n`nMicrosoft Azure Engineer"
                Write-Output "Rackspce Toll Free: (800) 961-4454"
                Write-Output "`n`n`n[TICKET_UPDATE=PUBLIC]"
                Write-Output "[TICKET_STATUS=CLOSED]"
             }
             #if false, restart the DNS service and then recheck the eventlog
             if ($DNSState -eq $false)
             {
             #check if othe DNS server is up before proceeding
                #Write-Output "DNS State Bad"
                $DNS = Get-Service DNS | Restart-Service
                $DNSState = Get-DNSEvents
                    if ($DNSState  -eq $true)
                    {
                        Write-Output "DNS State Good after service restart"
                        Write-Output "Hello Team,`n`nWrite message here that will be posted to ticket."
                        Write-Output "`n`nMicrosoft Azure Engineer"
                        Write-Output "Rackspce Toll Free: (800) 961-4454"
                        Write-Output "`n`n`n[TICKET_UPDATE=PUBLIC]"
                        Write-Output "[TICKET_STATUS=CLOSED]"
                    }
                    if ($DNSState -eq $false)
                    {
                            #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                            Write-Output "No remediation action taken"
                            Write-Output "Additional information to aid troubleshooting"
                            Write-Output "[TICKET_UPDATE=PRIVATE]"
                            Write-Output "[TICKET_STATUS=OPEN]"
                    }
              }
                
    }
    Catch
    {
        #Information to be added to private comment in ticket when unknown error occurs
        $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
        Write-Output "Script failed to run"
        Write-Output $ErrMsg
        Write-Output "[TICKET_UPDATE=PRIVATE]"
        Write-Output "[TICKET_STATUS=OPEN]"
    }
   


}
      
  
