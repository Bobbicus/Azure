 <#
    .SYNOPSIS
    Smart Ticket Script to remediate Azure Alert Id: directoryservice
       
    .DESCRIPTION
    Smart Ticket will check the state of the AD VMs in Azure and update the ticket accordingly.
    Supported: Yes
    Keywords: azure,smarttickets,directoryservice
    Prerequisites: No
    Makes changes: Yes
    .EXAMPLE
    Full command:  .\directoryservice.paas.ps1       
    .OUTPUTS
    Example output:



Hello,

Review the Smart Ticket automation AD server report to help investigate AD replication issues.


-----------------------------------------------
AD Server DNS information and VM running state:
-----------------------------------------------

VM Name     : DC-1
VNET DNS    : {172.16.195.4, 172.16.195.5}
NIC DNS     : No Custom DNS on NIC
Power State : VM running
VNET        : UKS-VNET01
Subnet      : UKS-VNET01-AD-PRD

VM Name     : DC-2
VNET DNS    : {172.16.195.4, 172.16.195.5}
NIC DNS     : {172.16.195.4, 172.16.195.5}
Power State : VM deallocated
VNET        : UKS-VNET01
Subnet      : UKS-VNET01-AD-PRD

-----------------------------------------------
AD Server health information:
-----------------------------------------------
subscriptionId : 13236a-ab3242234324-ASD123454-78090E
location       : uksouth
resourceGroup  : RG1
resource       : DC-2
status         : Unknown
summary        : We are currently unable to determine the health of this 
                 virtual machine
reason         : 
occuredTime    : 2018-08-08T15:38:16.3712445Z

------------------------------------------

Network Security Group Information:
------------------------------------------
Virtual Machine   : dc-1
Resource Group    : rg1
Associated Subnet : UKS-VNET01-AD-PRD
Outbound NSG      : UKS-VNET01-AD-PRD-NSG
------------------------------------------

Outbound NSG rules: Allow - HTTPS:
------------------------------------------
No AD port rules found (Ports: 53,135,445,389,88).

Outbound NSG rules: Deny - Any:
--------------------------------------------------

Name                     Priority Protocol SourcePortRange DestinationPortRange
----                     -------- -------- --------------- --------------------
securityRules/Port_8080       100 All      {0-65535}       {8181-8181}         
securityRules/Port_allow      101 All      {0-65535}       {8080-8080}         
securityRules/Port35          121 All      {0-65535}       {8003-8003}         


Review the rules (limited to -First 5)  and determine if AD traffic is allowed.


An Azure engineer will continue to troubleshoot manually.


Kind regards,




    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 08-Aug-2018 :: XX-XXX   ::   :: Release
#>

    
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
        $object = ConvertFrom-Json "$(get-content -Path C:\Users\oliv8274\Desktop\payload\ad.json)"
    }

    #Set Payload variables
    $VMName = ($object.Computer).Split(".")[0]
    $Subscription = $object.SubscriptionId
    $ResourceGroup = $object.ResourceGroup
    $ResourceId = $object.ResourceId

     
    <#hard coded for testing REMOVE before QC#Set Payload variables
    $VMName = "DC-1"#($object.Computer).ToLower()
    $Subscription = "13236a-ab3242234324-ASD123454-78090E" #$object.SubscriptionId
    $ResourceGroup = "RG1" #$object.ResourceGroup
    $ResourceId = $object.ResourceId
    #>
     
<#
#Get azure VM matching the name from payload
$VM =  Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroup 
#Get the NIC details
$VM.NetworkProfile.NetworkInterfaces
#$VM1 = Get-AzureRmVM -ResourceGroupName $ResourceGroup | Where-Object { $_.Name -eq "AD-VM-1"} | Get-AzureRmNetworkInterfaceIpConfig
#Extract the last field which is NIC name
$VMNIC =  $VM.NetworkProfile.NetworkInterfaces.id | split-path -Leaf
#Get NIC details 
$VMNICDetails = Get-AzureRmNetworkInterface -Name $VMNIC -ResourceGroupName $ResourceGroup
#Get DNS settings from NIC
$VMNICDNS = $VMNICDetails.DnsSettings.DnsServers

#Get the VM Nic details and split these
$VMVnetDetails = $VMNICDetails.IpConfigurations.Subnet.ID.Split("/")
#Extract just the VNET name from the NIC details 
$VMVnetDetails = $VMVnetDetails[8]
#Get virtual network details
$VNETInformation = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup  -Name $VMVnetDetails
#Get VNET DNS settings from 
$VNETDNSInformation = $VNETInformation.DhcpOptions.DnsServers
#************REVIEW***********
#If I only get VMs in same GR I will miss other regions.  Should I check for all AD servers in same sub  ?
#Get other VMs in same resource group with DC or AD in name.  I am limiting this for now but this needs to be reviewed.
#
#$ADVMS = Get-AzureRmVM -ResourceGroupName $ResourceGroup | Where-object {$_.Name -like "*DC*" -or $_.Name -like "*AD*"}
#>

#Using Find-azure resource is quickest way to find the VMS
#Find VMs with AD in name
$DCMatchVMS =  Find-AzureRmResource -ResourceNameContains "DC" -ResourceType Microsoft.Compute/virtualMachines -ResourceGroupNameEquals $ResourceGroup
#VMS with DC in name 
$ADMatchVMS =  Find-AzureRmResource -ResourceNameContains "AD" -ResourceType Microsoft.Compute/virtualMachines -ResourceGroupNameEquals $ResourceGroup
#Add name of all AD or DC VM servers to an Array excluding the device in the alert
$VMDCArray = @()
foreach ($VM1 in $ADMatchVMS)
{
   #if($VM1 -ne $VMName)
   #{
        $VMDCArray += $VM1.Name 
   #}
}
foreach ($VM2 in $DCMatchVMS)
{
   # if($VM2.Name -ne $VMName)
   #{
       $VMDCArray += $VM2.Name 
   #}
}


$ADVMOutput = @()
Foreach ($Server in $VMDCArray)
{
    $ServerInfo = Find-AzureRmResource -ResourceNameEquals $Server -ResourceType Microsoft.Compute/virtualMachines
    $ADVM1 =  Get-AzureRmVM -Name $Server -ResourceGroupName $ServerInfo.ResourceGroupName
    $ADVMState = Get-AzureRmVM -Name $Server -ResourceGroupName $ServerInfo.ResourceGroupName -Status
    $ADVMState = ($ADVMState.Statuses | Where-Object {$_.Code -like "*PowerState*"}).DisplayStatus
    #Get the PowerState of the VM
    #
    #$ADVM1 = Get-AzureRmVM -Name $ServerInfo.NAme -ResourceGroupName $ServerInfo.ResourceGRoupName -Status
    $VMpowerState = $ADVM1
    #Get the PowerState of the VM
    #####Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup
    #Get the NIC details
    $ADVM1RGName = $ADVM1.ResourceGroupName
    #$ADVM1.NetworkProfile.NetworkInterfaces
    #$VM1 = Get-AzureRmVM -ResourceGroupName $ResourceGroup | Where-Object { $_.Name -eq "USSCDVIM003AD01"} | Get-AzureRmNetworkInterfaceIpConfig
    #Extract the last field which is NIC name
    $VMNIC =  $ADVM1.NetworkProfile.NetworkInterfaces.id | split-path -Leaf
    #Get NIC details 
    $VMNICDetails = Get-AzureRmNetworkInterface -Name $VMNIC -ResourceGroupName $ADVM1RGName
    #Get DNS settings from NIC
    $VMNICDNS = $VMNICDetails.DnsSettings.DnsServers
    #$VMNICDNS
    if (-not $VMNICDNS)
    {
  
        $VMNICDNS = "No Custom DNS on NIC"
    }

    #Get the VM Nic details and split these
    $VMVnetDetails = $VMNICDetails.IpConfigurations.Subnet.ID.Split("/")
    #Extract just the VNET name from the NIC details 
    $VMVnetName = $VMVnetDetails[8]
    $VMVnetRG = $VMVnetDetails[4]
    $VMSubnet = $VMVnetDetails[10]
    #Get VNET DNS settings from 
    #Get virtual network details
    $VNETInformation = Get-AzureRmVirtualNetwork -ResourceGroupName $VMVnetRG  -Name $VMVnetName
    #Get VNET DNS settings from 
    $VNETDNSInformation = $VNETInformation.DhcpOptions.DnsServers
    if (-not $VNETDNSInformation)
    {
        $VNETDNSInformation = "No Custom DNS on VNET"
    }
    #Add properties to a new output object
    $item = New-Object PSObject
    $item | Add-member -MemberType NoteProperty -Name "VM Name" -Value $Server
    $item | Add-member -MemberType NoteProperty -Name "VNET DNS" -Value $VNETDNSInformation
    $item | Add-member -MemberType NoteProperty -Name "NIC DNS" -Value $VMNICDNS 
    $item | Add-member -MemberType NoteProperty -Name "Power State" -Value $ADVMState
    $item | Add-member -MemberType NoteProperty -Name "VNET" -Value $VMVnetName
    $item | Add-member -MemberType NoteProperty -Name "Subnet" -Value $VMSubnet
    $ADVMOutput +=$item

}

#VM health 

#Get Resource Health via REST API , input is taken from external parameter
function Get-AzureResourceHealth 
{
   Param(
    [Parameter(Mandatory=$false)]$Server1
    )     
    
    $ServerInfo1 = Find-AzureRmResource -ResourceNameEquals $Server1 -ResourceType Microsoft.Compute/virtualMachines
    #NOT NEEDED ~~~~~~~~~~~~~~~~~~~~~$ADVM2 =  Get-AzureRmVM -Name $Server1 -ResourceGroupName $ServerInfo1.ResourceGroupName
     $RG = $ServerInfo1.ResourceGroupName
    $ADVMState = Get-AzureRmVM -Name $Server1 -ResourceGroupName $ServerInfo1.ResourceGroupName -Status
    $ADVMState = ($ADVMState.Statuses | Where-Object {$_.Code -like "*PowerState*"}).DisplayStatus
    #Get the PowerState of the VM
    # Set Azure AD Tenant for selected Azure Subscription
    $adTenant = (Get-AzureRmContext).Tenant.id
    

    # Set parameter values for Azure AD auth to REST API
    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2" # Well-known client ID for Azure PowerShell
    $resourceAppIdURI = "https://management.core.windows.net/" # Resource URI for REST API
    $authority = "https://login.microsoftonline.com/$adTenant/" # Azure AD Tenant Authority
    
    # Create Authentication Context tied to Azure AD Tenant
    $authtoken = ((Get-AzureRmContext).TokenCache.ReadItems() | ? {$_.Authority -eq $authority}).AccessToken
    

    # Set REST API parameters
    $apiVersion = "2015-01-01"
    $contentType = "application/json;charset=utf-8"
    
    # Set HTTP request headers to include Authorization header
    $requestHeader = @{
       'Content-Type'='application\json'
       'Authorization'= "Bearer " + $authtoken
    }

    # Set initial URI for calling Resource Health REST API
    $VMuriRequest = "https://management.azure.com/subscriptions/$Subscription/resourceGroups" + `
        "/$($ServerInfo1.ResourceGroupName)/providers/Microsoft.Compute/virtualMachines/$($Server1)/providers" + `
        "/Microsoft.ResourceHealth/availabilityStatuses?api-version=$apiVersion"
    
    # Call Resource Health REST API
    $healthData = Invoke-RestMethod -Uri $VMuriRequest -Method Get -Headers $requestHeader -ContentType $contentType
    
    #confirm unplanned redeployment
    $script:confirmData = $healthdata.value.properties | Select-Object -First 2

    # Display Health Data for Azure resources in selected subscription, removed format list and only getting latest entry
    $formattedhealthdata = $healthData.value | Select-Object @{name='subscriptionId';Expression={$_.id.Split("/")[2]}},
    location,
            @{name='resourceGroup';Expression={$_.id.Split("/")[4]}},
            @{name='resource';Expression={$_.id.Split("/")[8]}},
            @{name='status';Expression={$_.properties.availabilityState}}, # ie., Available or Unavailable
            @{name='summary';Expression={$_.properties.summary}},
            @{name='reason';Expression={$_.properties.reason}},
            @{name='occuredTime';Expression={$_.properties.occuredTime}} -First 1


    return $formattedhealthdata
}
#GEt output from health data function and check through each VM to see if the last event was a shutdown event.
$VMHealthOutput = @()
Foreach ($Server in $VMDCArray)
{
    $HealthDataResults  = Get-AzureResourceHealth -Server1 $Server
        #if ($HealthDataResults.summary -eq "We are currently unable to determine the health of this virtual machine" -or $HealthDataResults.status -eq "Unavailable")
        if ($HealthDataResults.summary -eq "This virtual machine is stopping and deallocating as requested by an authorized user or process" -or $HealthDataResults.status -eq "Unavailable" -or $HealthDataResults.status -eq "Unknown")
        {

            $VMHealthOutput += $HealthDataResults 
        }
}

Function Get-OutboundNsg
{
        try
        {
            $VM =  Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroup
            #####Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup

            #Retrieve the Nic ID
            $nic = $vm.NetworkProfile.NetworkInterfaces.id | Split-Path -Leaf
            
            #Retrieve the effective NSGs for the given Nic
            $nsg = Get-AzureRmEffectiveNetworkSecurityGroup -NetworkInterfaceName $nic -ResourceGroupName $vm.ResourceGroupName -ErrorAction SilentlyContinue

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
            $OutBoundNsgADports= $OutBoundNsg | Where-Object {$_.DestinationPortRange -like "*53*" -or $_.DestinationPortRange -like "*135*" -or $_.DestinationPortRange -like "*445*" -or $_.DestinationPortRange -like "*389*" -or $_.DestinationPortRange -like "*88*"} 
            
            #Then filter by Deny rules
            $OutBoundNsgDeny = $OutBoundNsg | Where-Object {$_.Access -eq "Deny"} 

            #If Outbound Rules are present, print output.
            if ($OutBoundNsg -ne $null)
            {
                $NSGOutput = $null
                $NSGOutput += "Network Security Group Information:`n--------------------------------------------------"
                $NSGOutput += "`nVirtual Machine   : $($VMName)"
                $NSGOutput += "`nResource Group    : $($vm.ResourceGroupName)"
                $NSGOutput += "`nAssociated Subnet : $($subnet)"
                $NSGOutput += "`nOutbound NSG      : $($NsgName)"
                $NSGOutput += "`n`n"
                $NSGOutput += "Outbound NSG rules: Allow - HTTPS:`n"
                $NSGOutput += "--------------------------------------------------`n"
                if ($OutBoundNsgADports -ne $null)
                {
                    $NSGOutput += "$($OutBoundNsgADports| Sort-Object Priority | Select-Object Name, Priority, Protocol, SourcePortRange, DestinationPortRange, SourceAddressPrefix, DestinationAddressPrefix, Access -First 5 | Format-Table | Out-String)"
                }
                else 
                {
                    $NSGOutput += "No AD port rules found (Ports: 53,135,445,389,88).`n`n"
                }
                $NSGOutput += "Outbound NSG rules: Deny - Any:`n"
                $NSGOutput += "--------------------------------------------------`n"
                if ($OutBoundNsgDeny -ne $null)
                {
                    $NSGOutput += "$($OutBoundNsgDeny | Sort-Object Priority | Select-Object Name, Priority, Protocol, SourcePortRange, DestinationPortRange, SourceAddressPrefix, DestinationAddressPrefix, Access -First 5 | Format-Table | Out-String)"
                }
                else
                {
                    $NSGOutput += "No DENY rules found.`n`n"
                }
                $NSGOutput += "Review the rules (limited to -First 5)  and determine if AD traffic is allowed.`n`n"
            }
            #If no Outbound rules can be found, print output.
            elseif ($OutBoundNsg -eq $null)
            {
                $NSGOutput = $null
                $NSGOutput += "Network Security Group Information:`n-----------------------------------------"
                $NSGOutput += "`nVirtual Machine   : $($Workload)"
                $NSGOutput += "`nResource Group    : $($vm.ResourceGroupName)"
                $NSGOutput += "`nAssociated Subnet : $($subnet)"
                $NSGOutput += "`nOutbound NSG      : $($NsgName)"
                $NSGOutput += "`n-----------------------------------------`n`n"

            }
        }
        catch
        {
            $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
            Write-Output $ErrMsg 
        }
        return $NSGOutput
}
$NSGReport = Get-OutboundNsg

$ticketSignature = "Kind regards,`n`n"




Write-Output "[TICKET_UPDATE=PUBLIC]"
Write-Output "[TICKET_STATUS=ALERT RECEIVED]`n"
Write-Output "Hello,`n`nSmart Ticket automation has finished querying Azure. Please review the following Azure platform report:`n"
Write-Output "Domain Controller VM Information:`n--------------------------------------------------$($ADVMOutput | Format-List | Out-String)"
Write-Output "Azure Resource Health information:`n--------------------------------------------------$($VMHealthOutput | Out-String)"
Write-Output ""
$($NSGReport)
Write-Output "An Azure engineer will continue to troubleshoot manually.`n`n"
Write-Output "$($ticketSignature)"
