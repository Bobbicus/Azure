<#
    .SYNOPSIS
    <Basic Function Example, with single PSO output. Brief description of what script does. max 72 characters>
       
    .DESCRIPTION
    Full description: <Detailed description of what script does>
    supported: Yes
    Prerequisites: Yes/No
    Makes changes: No

    .EXAMPLE
    Full command: <example command>
    Description: <description of what the command does>
    Output: <List output>
       
    .OUTPUTS
    <List outputs>
        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Powell Shellington :: 01-JAN-2001 :: MC-111   :: Joe Bloggs  :: Release
#>

Function Get-FunctionName
{
  Try
    {
        #Requires -version 4.0
        #Your script code here
        #<code stuff>

        #Public update and close if issue resolved
        if($variable -eq $true)
        {
            Write-Output "Hello Team,`n`nWrite message here that will be posted to ticket."
            Write-Output "`n`nMicrosoft Azure Engineer"
            Write-Output "Rackspce Toll Free: (800) 961-4454"
            Write-Output "`n`n`n[TICKET_UPDATE=PUBLIC]"
            Write-Output "[TICKET_STATUS=CONFIRM SOLVED]"
        }
        else
        {
            #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
            Write-Output "No remediation action taken"
            Write-Output "Additional information to aid troubleshooting"
            Write-Output "[TICKET_UPDATE=PRIVATE]"
            Write-Output "[TICKET_STATUS=OPEN]"
        }
    
    }
    Catch
    {
        #Information to be added to private comment in ticket when unknown error occurs
        $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
        Write-Output "Script failed to run"
        Write-Output $ErrMsg
        Write-Output "[TICKET_UPDATE=PRIVATE]"
        Write-Output "[TICKET_STATUS=ALERT RECEIVED"
    }
}

