 <#
    .SYNOPSIS
    Check DFSR state by checking for latest success and error events
       
    .DESCRIPTION
    Full description: Check DFSR state by checking for latest success and error events
    supported: Yes
    keywords: DFS
    Prerequisites: Yes/No
    Makes changes: No
    Changes Made:


    .EXAMPLE
    Full command: Get-DFSRState
    Description: Compare last error events with last known good events to see if issue has been resolved
    Output: <List output>
       
    .OUTPUTS
    <List outputs>
        
    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 4
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 28-Nov-2017 :: N/A      :: Oliver Hurn  :: Release
#>

Param(    
[Parameter(Mandatory=$false)]$PayloadUri
)
Function Get-DFSRState
{
    Try
    {
          #Get state of DFS server to ensure it is present
          $DFSService =  Get-Service DFSR -ErrorAction SilentlyContinue 

            if ($DFSService.Status -eq $null)
            {
                 Write-Output "DFSR Service is not present."
                 exit
            }
             if ($DFSService.Status -eq "Running")
            {
                 $DFSServiceState =  "The DFSR Service is in a running state."
            }

            if ($DFSService.Status -eq "Stopped")
            {
                 $DFSServiceState =  "The DFSR service is in a Stopped state."
            }
        
            Function Get-DFSREvents
            {

            #Empty array to store the results of the check.  Are logs present, are good events newer than error events
            #For each error mark it as no logs present, good if issue has cleared, Alert Active if alert is still outstanding
            $EventIDResults = @()
            $object = Invoke-RestMethod -Uri $PayloadUri
            $ErrorID = $object.EventID
            
            <#Logic to add to test against a local payload
            $object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\payload.json)" 
            $ErrorID = $object.SearchResults.value.EventID
            or hard code the Error IDs
            #$ErrorID = "4612","5002"
            #>
                foreach ($ID in $ErrorID)
                {
                 
                #Check for the last instance of event ID 4013, DNS error event.  Will either pull ID from the alert payload or include all DNS errors
                        $LastErrorEvent = Get-WinEvent "DFS Replication" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq $ID} | Select -First 1 
                        #check if there is no matching error event
                        if ($LastErrorEvent -eq $null)
                        {
                            $LastErrorEventNull = $true
                        }
                        if ($LastErrorEvent -ne $null)
                        {
                            $ErrorDate = $LastErrorEvent.TimeCreated
                        }
            
                        #Depending on the error ID there is a differnt corresponding "good" event ID.  This loop carries out that check
                        if ($ID -eq "1202")
                        {
                            $LastGoodEvent = Get-WinEvent "DFS Replication" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq "1206"} | Select -First 1 
                        }
                        elseif ($ID -eq "5012")
                        {
                            $LastGoodEvent = Get-WinEvent "DFS Replication" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq "5004" -or $_.ID -eq "1104" } | Select -First 1 
                        }
                        elseif ($ID -eq "5002")
                        {
                           $LastGoodEvent = Get-WinEvent "DFS Replication" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq "5004"} | Select -First 1 
                        }

                        elseif ($ID -eq "4612")
                        {
                           $LastGoodEvent = Get-WinEvent "DFS Replication" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq "4604" -or $_.ID -eq "6018"} | Select -First 1 
                        }
                        else
                        {
                           $LastGoodEvent = $null
                        }

                        $GoodID =  $LastGoodEvent.ID
                        $GoodDate = $LastGoodEvent.TimeCreated

                        <# 31/10/2017 logic not needed for multi events
                        #foreach good ID check if a record exists

                        foreach ($ID in $GoodID)
                        {
                            #Check for last instance of Event ID 4 which show DNS is available
                            $LastGoodEvent = Get-WinEvent "DFS Replication" -ErrorAction SilentlyContinue | Where-Object {$_.ID -eq $ID} | Select -First 1 
                        }
                        #>
      
         
                        #Check if no good or error events are present.  If null mark this as no logs present
                        if ($LastGoodEvent -eq $null -and $LastErrorEvent -eq $null)
                        {
                            $AlertState =  "No Logs"
                            $item = New-Object PSObject -property @{}
                            $item | Add-member -MemberType NoteProperty -Name "Last Good Event" -Value "No Good Logs Present"
                            $item | Add-member -MemberType NoteProperty -Name "Good ID" -Value "n/a"
                            $item | Add-member -MemberType NoteProperty -Name "Last Error Event" -Value "No Error Logs Present"
                            $item | Add-member -MemberType NoteProperty -Name "Error ID" -Value $ID
                            $item | Add-member -MemberType NoteProperty -Name "Alert State" -Value $AlertState                            
                            $EventIDResults +=$item
                            #Write-Output "No Logs"
                       
                                #Switching to adding items to array $EventIDResults
                        }
                        #Check there are both good events and error events present.  It is also ok if there are only good events and no error events.  Logs may have cycled and cleared old events
                        if ($LastGoodEvent -ne $null -and $LastErrorEvent -eq $null -or $LastGoodEvent -ne $null -and $LastErrorEvent -ne $null)
                        {
                            #write-host "no error ID but a recent good event"
                            
                            #Check if the good event is newer than the error event
                            $AlertState = ($GoodDate) -gt ($ErrorDate)
                            if ($AlertState -eq  $False)
                            {
                                $AlertState =  "Unresolved"
                                <#
                                #Switching to adding items to array $EventIDResults
                                $AlertInfo = @{
                                LastGoodEvent = $GoodDate
                                LastErrorEvent = $ErrorDate
                                AlertState = $AlertState
                                }
                                #>
                                $item = New-Object PSObject -property @{}
                                $item | Add-member -MemberType NoteProperty -Name "Last Good Event" -Value $GoodDate
                                $item | Add-member -MemberType NoteProperty -Name "Good ID" -Value $GoodID 
                                $item | Add-member -MemberType NoteProperty -Name "Last Error Event" -Value $ErrorDate
                                $item | Add-member -MemberType NoteProperty -Name "Error ID" -Value $ID
                                $item | Add-member -MemberType NoteProperty -Name "Alert State" -Value $AlertState                                
                                $EventIDResults +=$item
                            }
                            if ($AlertState -eq  $True)
                            {
                                $AlertState =  "Cleared"
                                <#
                                #Switching to adding items to array $EventIDResults
                                $AlertInfo = @{
                                LastGoodEvent = $GoodDate
                                LastErrorEvent = $ErrorDate
                                AlertState = $AlertState
                                }
                                #>
                                $item = New-Object PSObject -property @{}
                                $item | Add-member -MemberType NoteProperty -Name "Last Good Event" -Value $GoodDate
                                $item | Add-member -MemberType NoteProperty -Name "Good ID" -Value $GoodID 
                                $item | Add-member -MemberType NoteProperty -Name "Last Error Event" -Value $ErrorDate
                                $item | Add-member -MemberType NoteProperty -Name "Error ID" -Value $ID
                                $item | Add-member -MemberType NoteProperty -Name "Alert State" -Value $AlertState 
                                $EventIDResults +=$item
                            }
                           # return $AlertInfo
                    
             
                        }
                        if ($LastGoodEvent -eq $null -and $LastErrorEvent -ne $null)
                        {
                            #write-host "recent error ID but no recent good event"
                            $GoodDate = $LastGoodEvent.TimeCreated
                            $AlertState = ($GoodDate) -gt ($ErrorDate)
                            $AlertState =  "Unresolved"
                            <#
                            #Switching to adding items to array $EventIDResults
                            $AlertInfo = @{
                            LastGoodEvent = $GoodDate
                            LastErrorEvent = $ErrorDate
                            AlertState = $AlertState
                            }
                            #>
                            $item = New-Object PSObject -property @{}
                            $item | Add-member -MemberType NoteProperty -Name "Last Good Event" -Value $GoodDate
                            $item | Add-member -MemberType NoteProperty -Name "Good ID" -Value $GoodID 
                            $item | Add-member -MemberType NoteProperty -Name "Last Error Event" -Value $ErrorDate
                            $item | Add-member -MemberType NoteProperty -Name "Error ID" -Value $ID
                            $item | Add-member -MemberType NoteProperty -Name "Alert State" -Value $AlertState 
                            $EventIDResults +=$item
                            #return $AlertInfo
                        }


        }
        return $EventIDResults 
    }
    $EventIDResults
                
                #Get VM information to add to ticket
                $OSType = (Get-CimInstance Win32_OperatingSystem).Caption
                $LocalIpAddress = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]

                $OSInfo = New-Object PSObject -property @{
                 "VM"  = "$env:computername"
                 "OS" =   "$OSType"
                 "IP" = "$LocalIpAddress" 

                }

                #Return DFS state True if cleared if a more recent good event exists
                $DFSRState = Get-DFSREvents
                $DFSAllAlertState = $DFSRState."Alert State" 

                   #$DFSRState.LastGoodEvent
                   #If there are some events that do not have a more recent "good" event then ticket needs further investigation
                   #The output shows the events so the tech knows which ones have not cleared
                   if ($DFSAllAlertState -contains "Unresolved" -and $DFSAllAlertState  -notcontains "No Logs")
                     {
                        #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                        Write-Output "[TICKET_UPDATE=PRIVATE]"
                        Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
                        Write-Output "Hello Team,`n`n"
                        Write-Output "This alert has not cleared. Please review the table below to see which alerts are in an 'Unresolved' state and thus require further investigation."
                        Write-Output "`nVirtual Machine  : $($OSInfo.VM)"
                        Write-Output "Operating System : $($OSInfo.OS)"
                        Write-Output "IPv4 Address     : $($OSinfo.IP)"  
                        Write-Output "`n-------------------------------------------"
                        Write-Output  $DFSRState
                        Write-Output "`n-------------------------------------------`n"
                        Write-Output  $DFSServiceState
                        Write-Output "`nMaking private update, marking ticket in alert recieved."
                        Write-Output "`n`nMicrosoft Azure Engineer"
                        Write-Output "Rackspace Toll Free: (800) 961-4454"
                     }
                     #If the output contains no logs only it may be that logs have been cleared.
                     if ($DFSAllAlertState -contains "No Logs" -and $DFSAllAlertState  -notcontains "Cleared" -and $DFSAllAlertState -notcontains "Unresolved")
                     {
                        #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                        Write-Output "[TICKET_UPDATE=PRIVATE]"
                        Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
                        Write-Output "Hello Team,`n`n"                       
                        Write-Output "No error events or good events were found in the logs. The DFS replication event log may have been cleared since this alert was triggered."
                        Write-Output "`nVirtual Machine  : $($OSInfo.VM)"
                        Write-Output "Operating System : $($OSInfo.OS)"
                        Write-Output "IPv4 Address     : $($OSinfo.IP)"  
                        Write-Output "`n-------------------------------------------"
                        Write-Output  $DFSRState
                        Write-Output "`n-------------------------------------------`n"
                        Write-Output  $DFSServiceState
                        Write-Output  "`nPlease investigate further."
                     }
                     #If the output contains no logs for some entries but some data for other logs. 
                     if ($DFSAllAlertState -contains "No Logs" -and ($DFSAllAlertState  -contains "Cleared" -or $DFSAllAlertState -contains "Unresolved"))
                     {
                        #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                        Write-Output "[TICKET_UPDATE=PRIVATE]"
                        Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
                        Write-Output "Hello Team,`n`n"                      
                        Write-Output "There are mutliple alerts, investigate the ones where there are no logs present, or where they are in a Unresolved state."
                        Write-Output "`nVirtual Machine  : $($OSInfo.VM)"
                        Write-Output "Operating System : $($OSInfo.OS)"
                        Write-Output "IPv4 Address     : $($OSinfo.IP)"  
                        Write-Output "`n-------------------------------------------"
                        Write-Output  $DFSRState
                        Write-Output "`n-------------------------------------------`n"
                        Write-Output  $DFSServiceState
                        Write-Output  "`nPlease investigate further."
                     }
                     #If the state does not contain NoLogs or Alert Active it means there are only good results and all alerts have cleared so ticket can be confirm solved
                     if ($DFSAllAlertState -notcontains "No Logs" -and $DFSAllAlertState  -notcontains "Unresolved" -and $DFSServiceState -contains "The DFSR Service is in a running state.")
                     {
                        Write-Output "[TICKET_UPDATE=PUBLIC]"
                        Write-Output "[TICKET_STATUS=CONFIRM SOLVED]"
                        Write-Output "Hello Team,`n`n" 
                        Write-Output "The alert cleared without intervention from Rackspace. Below is a list of the Error events and corresponding events where the alert has cleared."
                        Write-Output "`nVirtual Machine  : $($OSInfo.VM)"
                        Write-Output "Operating System : $($OSInfo.OS)"
                        Write-Output "IPv4 Address     : $($OSinfo.IP)" 
                        Write-Output "`n-------------------------------------------"
                        Write-Output  $DFSRState
                        Write-Output "`n-------------------------------------------`n"
                        Write-Output  $DFSServiceState
                        Write-Output "`nAs the alert has cleared we will mark this ticket as confirm solved. If you have any questions please let us know."
                        Write-Output "`n`nKind Regards,"
                        Write-Output "Microsoft Azure Engineer"
                        Write-Output "Rackspace Toll Free: (800) 961-4454"
                     }
                     if ($DFSAllAlertState -notcontains "No Logs" -and $DFSAllAlertState  -notcontains "Unresolved" -and $DFSServiceState -contains "The DFSR service is in a Stopped state.")
                     {
                        Write-Output "[TICKET_UPDATE=PRIVATE]"
                        Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
                        Write-Output "Hello Team,`n`n" 
                        Write-Output "The alert cleared without intervention from Rackspace, but the DFSr service is in a stopped state. Below is a list of the Error events and corresponding events where the alert has cleared."
                        Write-Output "`nVirtual Machine  : $($OSInfo.VM)"
                        Write-Output "Operating System : $($OSInfo.OS)"
                        Write-Output "IPv4 Address     : $($OSinfo.IP)" 
                        Write-Output "`n-------------------------------------------"
                        Write-Output  $DFSRState
                        Write-Output "`n-------------------------------------------`n"
                        Write-Output  $DFSServiceState
                        Write-Output "`nThe alert has cleared, but you need to investigate why the DFSR service is stopped."
                        Write-Output "`n`nKind Regards,"
                        Write-Output "Microsoft Azure Engineer"
                        Write-Output "Rackspace Toll Free: (800) 961-4454"
                     }
            
        }
        Catch
        {
            #Information to be added to private comment in ticket when unknown error occurs 
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
            Write-Output "Script failed to run."
            Write-Output $ErrMsg
            Write-Output "[TICKET_UPDATE=PRIVATE]"
            Write-Output "[TICKET_STATUS=ALERT RECEIVED"
        }

}
Get-DFSRState