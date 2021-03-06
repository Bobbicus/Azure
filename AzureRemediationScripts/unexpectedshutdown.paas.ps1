﻿<#
    .SYNOPSIS
    Checks VM Power State and retrieves recent Azure Health events.
       
    .DESCRIPTION
    Checks VM Power State and retrieves recent Azure Health events to confirm Hypervisor guest live migration occurance.

    Supported: Yes
    Keywords: azure,healthevent,reboot
    Prerequisites: No
    Makes changes: Yes

    .EXAMPLE
    Full command:  .\unexpectedshutdown.paas.ps1
    Description: Checks VM Power State and retrieves recent Azure Health events to confirm Hypervisor guest live migration occurance.
       
    .OUTPUTS
    Example output:
 
    Hello Team,

    The script has confirmed VM: jumpy is available and running, after it had recently been redeployed to a new hypervisor:

    Virtual Machine Details:
    ------------------------------------------------------------
    VM Resource    : VM1
    Power State    : VM running
    Resource Group : RG1

    Recent Health Events:
    ------------------------------------------------------------

    subscriptionId : 13236a-ab3242234324-ASD123454-78090E
    location       : northeurope
    resourceGroup  : RG1
    resource       : VM1
    status         : Available
    summary        : There aren't any known Azure platform problems affecting this virtual machine
    reason         : 
    occuredTime    : 2018-04-16T08:45:27Z

    subscriptionId : 13236a-ab3242234324-ASD123454-78090E
    location       : northeurope
    resourceGroup  : RG1
    resource       : vm1
    status         : Unavailable
    summary        : We're sorry, your virtual machine isn't available and it is being redeployed due to an unexpected failure on the host server
    reason         : Unplanned
    occuredTime    : 2018-04-16T08:44:27Z

    This ticket will be set to Confirm Solved status, please let us know if you have any questions.

    Kind regards,

        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 06-Jun-2019 :: XX-XXX   ::             :: Release


#>  
    
    
    <#
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
        $object = ConvertFrom-Json "$(get-content -Path C:\temp\shutdown1.json)"
    }
    
    #Set Payload variables
    $vmName = $object.ResourceId | Split-Path -Leaf
    $Subscription = $object.SubscriptionId
    $ResourceGroup = $object.ResourceGroup
    $ResourceId = $object.ResourceId
    #endregion
    #>


#Get subscription from user input
$Subscription = Get-AzSubscription | Out-GridView -OutputMode Single
#Set active subscription
Set-AzContext -Subscription $Subscription.Id

#Get VM from user input
$vm = Get-AzVM | Out-GridView -OutputMode Single
$vmName = $VM.Name

#Get resource group and ID from VM details
$ResourceGroup = $VM.ResourceGroupName
$ResourceId = $VM.Id

#Ticket Signature
$ticketSignature = "Kind regards,`n`n"
#Main Function
Function Get-UnexpectedShutdown
{
    try
    {
    #Function to get VM State
    Function Get-VmState
    {
        try
        {
            #Create VM variable
            $vm = Get-AzVM -Name $vmName -ResourceGroupName $ResourceGroup -Status

            #Get the PowerState of the VM
            ($vm.Statuses | Where-Object {$_.Code -like "*PowerState*"}).DisplayStatus
        }
        catch
        {
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
            Write-Output $ErrMsg 
        }
    
    }
        #Set $powerState variable
        $powerState = Get-VmState

    #Get Resource Health via REST API
    function Get-AzureResourceHealth 
    {
    
        # Set Azure AD Tenant for selected Azure Subscription
        $adTenant = (Get-AzContext).Tenant.id
    

        # Set parameter values for Azure AD auth to REST API
        $clientId = "1950a258-227b-4e31-a9cf-717495945fc2" # Well-known client ID for Azure PowerShell
        $resourceAppIdURI = "https://management.core.windows.net/" # Resource URI for REST API
        $authority = "https://login.microsoftonline.com/$adTenant/" # Azure AD Tenant Authority
    
        # Create Authentication Context tied to Azure AD Tenant, I had to add [0] as I was getting multiple tokens.
        #########
        #  TEST
        #########
        $authtoken = ((Get-AzContext).TokenCache.ReadItems() | Where-Object {$_.Authority -eq $authority}).AccessToken[0]

        # Set REST API parameters
        $apiVersion = "2015-01-01"
        $contentType = "application/json;charset=utf-8"
    
        # Set HTTP request headers to include Authorization header
        $requestHeader = @{
            'Content-Type'='application\json'
            'Authorization'= "Bearer " + $authtoken
        }

        # Set initial URI for calling Resource Health REST API
        $VMuriRequest = "https://management.azure.com/subscriptions/$subscription/resourceGroups" + `
            "/$($ResourceGroup)/providers/Microsoft.Compute/virtualMachines/$($vmName)/providers" + `
            "/Microsoft.ResourceHealth/availabilityStatuses?api-version=$apiVersion"
    
        # Call Resource Health REST API
        $healthData = Invoke-RestMethod -Uri $VMuriRequest -Method Get -Headers $requestHeader -ContentType $contentType
    
        #confirm unplanned redeployment
        $script:confirmData = $healthdata.value.properties | Select-Object -First 2

        # Display Health Data for Azure resources in selected subscription
        $formattedhealthdata = $healthData.value | Select-Object `
                @{n='subscriptionId';e={$_.id.Split("/")[2]}},
                location,
                @{n='resourceGroup';e={$_.id.Split("/")[4]}},
                @{n='resource';e={$_.id.Split("/")[8]}},
                @{n='status';e={$_.properties.availabilityState}}, # ie., Available or Unavailable
                @{n='summary';e={$_.properties.summary}},
                @{n='reason';e={$_.properties.reasonType}},
                @{n='occuredTime';e={$_.properties.occuredTime}} -First 2 |
                Format-List

        return $formattedhealthdata
        }
            #Add Output to variable and convert to String
            $healthOutput = Get-AzureResourceHealth | Out-String

            #If VM State is healthy, then output and close ticket
            if ($powerState -eq "VM running" -and $confirmData.reasonType[1] -eq "Unplanned" -and $confirmData.availabilityState[0] -eq "Available")
            {
                $Output1 = $null
                $Output1 += "Hello Team,`n`nThis script  has confirmed VM: $($VMName) is available and running, after it had recently been redeployed to a new hypervisor:`n"
                $Output1 += "`n`Virtual Machine Details:`n------------------------------------------------------------`n"
                $Output1 += "VM Resource    : $($vmName)`n"
                $Output1 += "Power State    : $($powerState)`n"
                $Output1 += "Resource Group : $($ResourceGroup)`n`n"
                $Output1 += "Recent Health Events:`n"
                $Output1 += "------------------------------------------------------------"
                $Output1 += "$healthOutput"
                $Output1 += "This ticket will be set to Confirm Solved status, please let us know if you have any questions.`n`n"
                $Output1 += "$($ticketSignature)"  
                $Output1
        }
        #If VM state is not healthy, output and leave ticket open for further investigation
        else
        {
            $Output2 = $null
            $Output2 += "Hello Team,`n`nThis script has confirmed the PowerState of VM: $($VMName) to be - $($powerState):"
            $Output2 += "`n`nVirtual Machine Details:`n------------------------------------------------------------`n"
            $Output2 += "VM Resource    : $($vmName)`n"
            $Output2 += "Power State    : $($powerState)`n"
            $Output2 += "Resource Group : $($ResourceGroup)`n`n"
            $Output2 += "Recent Health Events:`n"
            $Output2 += "------------------------------------------------------------"
            $Output2 += "$healthOutput"
            $Output2 += "An engineer will review this ticket shortly and they will continue troubleshooting.`n`n"
            $Output2 += "$($ticketSignature)"  
            $Output2      
        }
    }
    catch
    {
        $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
        Write-Output $ErrMsg
    }
}

#Execute function
Get-UnexpectedShutdown