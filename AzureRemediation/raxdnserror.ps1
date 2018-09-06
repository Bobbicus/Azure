<#
    .SYNOPSIS
    Check DNS state by checking for latest success and error events
       
    .DESCRIPTION
    Full description: Check DNS state by checking for latest success and error events, restart DNS service if required
    supported: Yes
    keywords: DNS
    Prerequisites: Yes/No
    Makes changes: Yes
    Changes Made:
    Restarts DNS server service if required

    .EXAMPLE
    Full command: Get-DNSState
    Description: <description of what the command does>
    Output: 

        Date/time of last good event ID


        Monday, October 30, 2017 3:50:10 PM

        LastErrorEvent  ID:
        Monday, October 30, 2017 3:49:51 PM

        Error Event  ID: 4013

        Marking ticket confirm solved.


        Microsoft Azure Engineer
        Racksapce Toll Free: (800) 961-4454


    .OUTPUTS
    <List outputs>
        
    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 4
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 31-Oct-2017 :: N/A      :: Chris Clark  :: Release
    1.1     :: Bob Larkin         :: 28-Nov-2017 :: N/A      :: Oliver Hurn  :: Release
#>
Param(
    [Parameter(Mandatory=$false)]$PayloadUri
    )
    
Function Get-DNSState
{
 
    Try
    {

    #Check if DNS service is present and what state it is in
    $DNSService =  Get-Service DNS -ErrorAction SilentlyContinue 

    if ($DNSService.Status -eq $null)
    {
         Write-Output "Hello Team,`n"
         Write-Output "`nThis alert has not cleared, the script ran but failed to find the DNS service. Please investigate further."
         Write-Output "[TICKET_UPDATE=PRIVATE]"
         Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
         exit
    }
     if ($DNSService.Status -eq "Running")
    {
         $DNSServiceState = "The DNS Service is in a running state."
    }

    if ($DNSService.Status -eq "Stopped")
    {
         $DNSServiceState = "The DNS Service in Stopped state."
    }

        function Get-DNSEvents
        {
        
            $object = Invoke-RestMethod -Uri $PayloadUri
            $ErrorIDAll = $object.EventID
 #New Logic handles multiple event IDs from the payload. As all events are deemed to have cleared if we have an Event ID 4 
            #This script gets the latest Error event and uses this to compare to the last good event
           

            $ErrorEventArray = @()
            #Check the logs that match all the event IDs from the payload.  This loop will add a null value if no events are found
            foreach ($ErrorEvent in $ErrorIDAll)
            {
                $MultiErrorEvent = Get-WinEvent "DNS Server" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq $ErrorEvent} | Select -First 1 
                if ($MultiErrorEvent -ne $null)
                {
                $item = New-Object PSObject -property @{}
                $item | Add-member -MemberType NoteProperty -Name "EventID" -Value "$ErrorEvent"
                $item | Add-member -MemberType NoteProperty -Name "TimeCreated"  -Value $MultiErrorEvent.TimeCreated
                $ErrorEventArray +=$item
                }
                if ($MultiErrorEvent -eq $null)
                {
                $item = New-Object PSObject -property @{}
                $item | Add-member -MemberType NoteProperty -Name "EventID" -Value "$Null"
                $item | Add-member -MemberType NoteProperty -Name "TimeCreated"  -Value $Null
                $ErrorEventArray +=$item
                }

            }
            
            #Check if the event contain a value
            $LastErrorEvent = $ErrorEventArray | Sort-Object {[datetime]$_."TimeCreated"} -ErrorAction SilentlyContinue | select -Last 1
            if ($LastErrorEvent.TimeCreated -ne $null)
            {
                $ErrorID = $LastErrorEvent.EventID
                $ErrorDate = $LastErrorEvent.TimeCreated
            }
            if ($LastErrorEvent.TimeCreated -eq $null)
            {
                $LastErrorEvent = $null
            }
           

        #Write-Output $ErrorID
         
      <#   
            #This logic is for when we can read the payload
            $object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\payload.json)" 
            $ErrorIDAll = $object.SearchResults.value.EventID
            #will there be more than one event ID on any ticket ? 

            $ErrorID=@()
            foreach($ErrId in $dataDNSerror){
            $ErrorID += $ErrId.value.EventID
        
            }
            $ErrorID
          
            #Check for the last instance of event ID matching event ID from the JSON payload, DNS error event.  Will either pull ID from the alert payload or include all DNS errors
            $LastErrorEvent = Get-WinEvent "DNS Server" | Where-Object {$_.ID -eq $ErrID} | Select -First 1 
            $ErrorDate = $LastErrorEvent.TimeCreated
              #>

            #Check for the last instance of event ID 4013, DNS error event.  Will either pull ID from the alert payload or include all DNS errors
            #Remove 14/11/2017 logic now in loop above
            #$LastErrorEvent = Get-WinEvent "DNS Server" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq $ErrorID} | Select -First 1 
            #check if there is no matching error event
            #Remnoved unused variable 14/11/2017
            <#if ($LastErrorEvent -eq $null)
            {
                $LastErrorEventNull = $true
            }#>
           
            

            #Check for last instance of Event ID 4 which show DNS is available
            $LastGoodEvent = Get-WinEvent "DNS Server" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq "4"} | Select -First 1 
            #check if there is no matching good event
            if ($LastGoodEvent -eq $null -and $LastErrorEvent -eq $null)
            {
                $AlertState =  "NoLogs"
                return $AlertState
                #Write-Output "NoLogs"
            }
            
            elseif (($LastGoodEvent -ne $null -and $LastErrorEvent -eq $null) -or ($LastGoodEvent -ne $null -and $LastErrorEvent -ne $null))
            {
                #write-host "no error ID but a recent good event"
                $GoodDate = $LastGoodEvent.TimeCreated

                $AlertState = ($GoodDate) -gt ($ErrorDate)
                if ($AlertState -eq  $False)
                    {
                        $AlertState =  "Bad"
                        $AlertInfo = @{
                        LastGoodEvent = $GoodDate
                        #ErrorID = $ErrorID
                        LastErrorEvent = $ErrorEventArray
                        AlertState = $AlertState
                        }
                    }
                    elseif ($AlertState -eq  $True)
                    {
                        $AlertState =  "Good"
                        $AlertInfo = @{
                        LastGoodEvent = $GoodDate
                        #ErrorID = $ErrorID
                        LastErrorEvent = $ErrorEventArray
                        AlertState = $AlertState
                        }
                    }
                    return $AlertInfo
                    
            }
            elseif ($LastGoodEvent -eq $null -and $LastErrorEvent -ne $null)
            {
                #write-host "recent error ID but no recent good event"
                $GoodDate = $LastGoodEvent.TimeCreated
                $AlertState = ($GoodDate) -gt ($ErrorDate)
                $AlertState =  "Bad"
                $AlertInfo = @{
                LastGoodEvent = $GoodDate
                #ErrorID = $ErrorID
                LastErrorEvent = $ErrorEventArray
                AlertState = $AlertState
                }
                return $AlertInfo
                
            }
           
            #Compare the error and good event to see if the good event is more recent

        }
              
        #Get OS Information for final output
        $OSType = (Get-CimInstance Win32_OperatingSystem).Caption
        $LocalIpAddress = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
        $OSInfo = New-Object PSObject -property @{
                 "VM"  = "$env:computername"
                 "OS" =   "$OSType"
                 "IP" = "$LocalIpAddress"
                }
        #Return DNS state True if event ID 4 is newer than the error event
        $DNSState = Get-DNSEvents
        
        #$DNSState.LastErrorEvent.TimeCreated
        #$DNSState.LastErrorEvent.EventID
             if ($DNSState.AlertState   -eq "Good")
             {
                Write-Output "Hello Team,"
                Write-Output "`nThe alert cleared without intervention from Rackspace. The latest good event ID is more recent than the error event. Review the details below for more information:`n"
                Write-Output "`nVirtual Machine  : $($OSInfo.VM)"
                Write-Output "Operating System : $($OSInfo.OS)"
                Write-Output "IPv4 Address     : $($OSinfo.IP)`n"  
                Write-Output "`nMost recent Good Event:"
                Write-Output "-----------------------------------------------------"
                Write-Output "EventID     : 4"
                #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                $LGE =  $DNSState.LastGoodEvent | Out-String
                $LGEFinal = $LGE.Trim()
                Write-Output "Event Time  : $($LGEFinal)"
                Write-Output "-----------------------------------------------------"
                Write-Output "`nMost recent Error Event:"  
                Write-Output "-----------------------------------------------------"
                Write-Output "EventID     : $($DNSState.LastErrorEvent.EventID)"
                #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                $LEE = $DNSState.LastErrorEvent.TimeCreated | Out-String
                $LEEFInal = $LEE.Trim()
                Write-Output "Event Time  : $($LEEFinal)"
                Write-Output "-----------------------------------------------------"
                #Write-Output "$("`nError Event  ID: ")$($DNSState.ErrorID)"
                Write-Output "`nService status:"
                Write-Output "-----------------------------------------------------"
                Write-Output $DNSServiceState
                Write-Output "-----------------------------------------------------"
                Write-Output "`nAs this alert has cleared we will mark this ticket as confirm solved. If you have any questions please let us know."
                Write-Output "`n`nKind Regards,"
                Write-Output "`nMicrosoft Azure Engineer"
                Write-Output "Rackspace Toll Free: (800) 961-4454"
                Write-Output "[TICKET_UPDATE=PUBLIC]"
                Write-Output "[TICKET_STATUS=CONFIRM SOLVED]"
             }
             if ($DNSState.AlertState -eq "Bad")
             {
                #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                Write-Output "Hello Team,`n"
                Write-Output "The alert has not cleared. The most recent error event is newer than the last reported good event. Review details below and investigate further:`n"
                Write-Output "Virtual Machine  : $($OSInfo.VM)"
                Write-Output "Operating System : $($OSInfo.OS)"
                Write-Output "IPv4 Address     : $($OSinfo.IP)`n"                
                Write-Output "`nMost recent Error Event:"  
                Write-Output "-----------------------------------------------------"
                Write-Output "EventID     : $($DNSState.LastErrorEvent.EventID)"
                #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                $LEE = $DNSState.LastErrorEvent.TimeCreated | Out-String
                $LEEFInal = $LEE.Trim()
                Write-Output "Event Time  : $($LEEFinal)"
                Write-Output "-----------------------------------------------------"
                Write-Output "`nMost recent Good Event:"
                Write-Output "-----------------------------------------------------"
                Write-Output "EventID     : 4"
                #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                $LGE =  $DNSState.LastGoodEvent | Out-String
                $LGEFinal = $LGE.Trim()
                Write-Output "Event Time  : $($LGEFinal)"
                Write-Output "-----------------------------------------------------"
                Write-Output "`nService status:"
                Write-Output "-----------------------------------------------------"
                Write-Output $DNSServiceState
                Write-Output "-----------------------------------------------------"
                Write-Output "[TICKET_UPDATE=PRIVATE]"
                Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
             }
             if ($DNSState -eq "NoLogs")
             {
                #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                Write-Output "Hello Team,`n" 
                Write-Output "The script ran but found no matching DNS events. The DNS event logs may have been cleared since this alert was triggered."                
                Write-Output "`nVirtual Machine  : $($OSInfo.VM)"
                Write-Output "Operating System : $($OSInfo.OS)"
                Write-Output "IPv4 Address     : $($OSinfo.IP)" 
                Write-Output "`nPlease Investigate further.`n"
                Write-Output "[TICKET_UPDATE=PRIVATE]"
                Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
             }
             #if false, restart the DNS service and then recheck the eventlog
             <#
             #Removing logic to restart DNS service
             if ($DNSState -eq $false)
             {
                #check if othe DNS server is up before proceeding
                #Write-Output "DNS State Bad"
                

                $DNS = Get-Service DNS | Restart-Service
                $DNSState = Get-DNSEvents
                    if ($DNSState  -eq $true)
                    {
                        
                        Write-Output "Hello Team,`n`nDNS service restarted."
                        Write-Output "DNS State Good after service restart"
                        Write-Output "`n`nMicrosoft Azure Engineer"
                        Write-Output "Rackspce Toll Free: (800) 961-4454"
                        Write-Output "[TICKET_UPDATE=PUBLIC]"
                        Write-Output "[TICKET_STATUS=CONFIRM SOLVED]"
                    }
                    #>  
                                  
    }
    Catch
    {
        #Information to be added to private comment in ticket when unknown error occurs
        $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
        Write-Output "Hello Team,`n"         
        Write-Output "The script failed to run, see error message below:`n"
        Write-Output $ErrMsg
        Write-Output "`nPlease Investigate further."
        Write-Output "[TICKET_UPDATE=PRIVATE]"
        Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
    }

}

Get-DNSState