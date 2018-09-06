#Written by Patrick
function Get-VmIP
{
    [CmdletBinding()]
    Param
    (
        # Param1 Provide the Ticket# from CORE
        [string][Parameter(ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $ticket
    )

    Begin
    {
        if ($ticket -eq $null) { read-host "Provide ticket#" }
    }
    Process
    {
        $message = (Get-CoreTicketMessage -ID (((Get-CoreTicketContents -ticket $ticket).messages[0]).load_value)).text
        $subscriptionID = ($message.Split("`n") | where {$_ -like "*`"SubscriptionId`":*"}).split("`"")[-2]
        if ($subscriptionID -eq "SubscriptionID"){
            "Ticket does not contain a valid subscription ID"#search through all EY subscriptions for the VM
        }
        $Entity = $null
        $Entity = ($message.Split("`n") | where {$_ -like "*`"Entity Name`":*"}).split("`"")[-2]
        
        if (!($Entity)){
            $entity = ($message.Split("`n") | where {$_ -like "*`"Computer`":*"}).split("`"")[-2]
        }
        
        Login-MSCloudSubscription -subscription (Get-MSCloudSubscription -AzureSubscriptionId $subscriptionID)
        
        if ($Entity.Split(".").Count -gt 1){
            $resource = Find-AzureRmResource -ResourceNameEquals $Entity.Split(".")[0]
        }
        else {
            $resource = Find-AzureRmResource -ResourceNameEquals $Entity
        }

        $vm = Get-AzureRmVM -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
        $nid = $vm.NetworkProfile.NetworkInterfaces.id
        $ni = Get-AzureRmNetworkInterface -Name $nid.Split("/")[-1] -ResourceGroupName $nid.Split("/")[4]
        $ip = ($ni.IpConfigurations).PrivateIpAddress
        $OSSKU = "$($vm.StorageProfile.ImageReference.Offer)" + " " + "$($vm.StorageProfile.ImageReference.SKU)"
        
    }
    End
    {
        $properties = [ordered]@{
            VMname = $vm.Name
            VMResourceGroup = $vm.ResourceGroupName
            VMPrivateIP = $ip
            VMOS = $OSSKU
            VMSubscription = $subscriptionID
        }
        $vmreport = New-Object -TypeName PSObject -Property $properties
        $vmreport | fl
    }
}
	