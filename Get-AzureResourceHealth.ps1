function Get-AzureResourceHealth {
    
    <#
    .Synopsis
       Uses Azure Resource Health REST API to report resource health on a VM
    .DESCRIPTION
       Uses Azure Resource Health REST API to report resource health on a VM, as it uses the AzureAccess global variables requires that you're authenitcated to the subscription you're reporting on.
    .EXAMPLE
       Get-AzureResourceHealth (prompts for VM selection)
    .EXAMPLE
       Get-AzureResourceHealth -device rlb1-495-5051027


    #>

    #[CmdletBinding()]
    #Param
    #(
      #  [string]$device  
    #)
    $device = $null
    if ($device -eq $null){
        # Select VM
        $vm = Find-AzureRmResource -ResourceType microsoft.compute/virtualmachines | Select Name, SubscriptionId, Location, ResourceGroupName | ogv -PassThru -Title 'Select VM'
    }
    else {
        # Find VM
        $vm = Find-AzureRmResource -ResourceNameEquals $device -ResourceType microsoft.compute/virtualmachines | Select Name, SubscriptionId, Location, ResourceGroupName
    }
    
    # Select Azure Subscription - can automate with specific Azure subscriptionId
    $subscriptionId = $vm.SubscriptionId
    
    # Set Azure AD Tenant for selected Azure Subscription
    $adTenant = (Get-AzureRmSubscription -SubscriptionId $subscriptionId).TenantId
    
    # Set parameter values for Azure AD auth to REST API
    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2" # Well-known client ID for Azure PowerShell
    $resourceAppIdURI = "https://management.core.windows.net/" # Resource URI for REST API
    $authority = (Get-azurermcontext).Account.tenants[0] # Azure AD Tenant Authority

    # Load Microsoft.ADAL.PowerShell module in separate window
    Get-ADALAccessToken -ClientId $clientId -ResourceId $resourceAppIdURI -Username $AzureSubscriptionUser -Password $AzureSubscriptionPass -AuthorityName $authority > $env:TEMP\$($subscriptionId)
    
    # Acquire token
    $authHeader = @{
       'Content-Type'='application\json'
       'Authorization'= "Bearer " + (Get-Content $env:TEMP\$($subscriptionId))
    }
    
    # Set REST API parameters
    $apiVersion = "2015-01-01"
    $contentType = "application/json;charset=utf-8"
    
    # Set initial URI for calling Resource Health REST API
    $VMuriRequest = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups" + `
        "/$($VM.ResourceGroupName)/providers/Microsoft.Compute/virtualMachines/$($VM.Name)/providers" + `
        "/Microsoft.ResourceHealth/availabilityStatuses?api-version=$apiVersion"
    
    # Call Resource Health REST API
    $healthData = Invoke-RestMethod -Uri $VMuriRequest -Method Get -Headers $authHeader -ContentType $contentType
    
    # Display Health Data for Azure resources in selected subscription
    $healthData.value | Select-Object `
            @{n='subscriptionId';e={$_.id.Split("/")[2]}},
            location,
            @{n='resourceGroup';e={$_.id.Split("/")[4]}},
            @{n='resource';e={$_.id.Split("/")[8]}},
            @{n='status';e={$_.properties.availabilityState}}, # ie., Available or Unavailable
            @{n='summary';e={$_.properties.summary}},
            @{n='reason';e={$_.properties.reasonType}},
            @{n='occuredTime';e={$_.properties.occuredTime}} |
            Format-List
            
}
