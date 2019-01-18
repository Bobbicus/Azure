 <#
    .SYNOPSIS
    Collects repdmin /replmon data and prints a report.
       
    .DESCRIPTION
    Collects repdmin /replmon data and prints a report.

    Supported: Yes
    Keywords: azure,ad,replication,smarttickets
    Prerequisites: No
    Makes changes: Yes

    .EXAMPLE
    Full command:  .\raxdirectoryservice.ps1
    Description: Collects repdmin /replmon data and prints a report.
       
    .OUTPUTS
    Example output:
 

        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0

    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Oliver Hurn        :: 07-APR-2018 :: XX-XXX   :: ---         :: Release
#>
 
    #Script Uri
    Param(
    [Parameter(Mandatory=$false)]$PayloadUri
    )
    #>

    #region Testing
    #uncomment for testing
    #$object = ConvertFrom-Json "$(get-content -Path C:\Users\oliv8274\Desktop\payload\ad.json)"

    #endregion
try
{
    #region Script Variables
    #Ingest the payload
    $object = Invoke-RestMethod -Uri $PayloadUri
    
    #Set payload variables
    $ResourceGroupName = $object.ResourceGroup
    $Subscription = $object.SubscriptionId
    $Computer = $object.Computer
    #$ResourceId = ($object.resourceid | Split-Path -Parent).Replace("\","/")
    #endregion

    #region ########### cmd commands ##############

    $repsum = repadmin /replsum

    #endregion
 
    if ($repsum -ne $null)
    {
        Write-Output "Active Directory Replication Summary for: $($Computer)"
        Write-Output "---------------------------------------------------------------------------------"
        $repsum
        Write-Output "---------------------------------------------------------------------------------`n"
       #Write-Output "Smart Ticket automation is checking for deallocated VMs in Azure, another update will follow shortly...`n"
        Write-Output "[TICKET_UPDATE=PRIVATE]"
        Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
       #Write-Output "[TICKET_PAAS_REMEDIATION=TRUE]"
       #Write-Output "[TICKET_PAAS_DEVICE=$($ResourceId)"
    }
    elseif ($repsum -eq $null)
    {
        Write-Output "repadmin /replsum couldn't collect any data. Please troubleshoot manually."
        Write-Output "[TICKET_UPDATE=PRIVATE]"
        Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
    }
    else
    {
        Write-Output "Smart Ticket Automation failed to run."
        Write-Output "[TICKET_UPDATE=PRIVATE]"
        Write-Output "[TICKET_STATUS=ALERT RECEIVED]"
    }
}
catch
{
    $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
    Write-Output $ErrMsg.
}