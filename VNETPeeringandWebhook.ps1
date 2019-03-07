
##########
#Stage 1 #
##########
#manually create peering.

$VNET1 = Get-AzureRmVirtualNetwork -ResourceGroupName BobRG1 -Name "BobRG1-vnet"
$VNET2 = Get-AzureRmVirtualNetwork -ResourceGroupName BobRG1 -Name "VNET2"

# Peer VNet1 to VNet2.
Add-AzureRmVirtualNetworkPeering -Name 'LinkVnet1ToVnet2' -VirtualNetwork $vnet1 -RemoteVirtualNetworkId $vnet2.Id

# Peer VNet2 to VNet1.
Add-AzureRmVirtualNetworkPeering -Name 'LinkVnet2ToVnet1' -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet1.Id


##########
#Stage 2 #
##########
#CODE for the AUtomation runbook

Param 
(    
        [Parameter(Mandatory=$false)] 
        [object] 
        $WebhookData
) 

$VNETID = (ConvertFrom-Json -InputObject $WebHookData.RequestBody)
$DESTVNET = $VNETID.VNETID2

$connectionName = 'AzureRunAsConnection'
$AzureSubscriptionId = "fea6590d-874f-42d4-a36d-4513ef125012"
try
 {
     # Get the connection "AzureRunAsConnection "
     $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

     "Logging in to Azure..."
     Add-AzureRmAccount `
         -ServicePrincipal `
         -TenantId $servicePrincipalConnection.TenantId `
         -ApplicationId $servicePrincipalConnection.ApplicationId `
         -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 

        Select-AzureRmSubscription -SubscriptionId $AzureSubscriptionId 
$VNET1 = Get-AzureRmVirtualNetwork -ResourceGroupName BobRG1 -Name BobRG1-vnet
        # Peer VNet1 to VNet2.
Add-AzureRmVirtualNetworkPeering -Name 'LinkVnet1ToVnet2' -VirtualNetwork $VNET1 -RemoteVirtualNetworkId $DESTVNET
       
    }
catch {
            if (!$servicePrincipalConnection)
            {
                $ErrorMessage = "Connection $connectionName not found."
                throw $ErrorMessage
            } 
            else
            {
                Write-Error -Message $_.Exception
                throw $_.Exception
            }
        }   
    
      

##########
#Stage 3 #
##########

#This is the code needed to invoke a web request to use the webhook and pass it
#the parameter of the VNET ID

$uri = "https://s12events.azure-automation.net/webhooks?token=YdR5Z6FQocqTuJtC2FTombM3P3Yuq15X91SuMoLDhTI%3d"

$VNETID1  = @{ "VNETID2" ="/subscriptions/fea6590d-874f-42d4-a36d-4513ef125012/resourceGroups/BobRG1/providers/Microsoft.Network/virtualNetworks/VNET2"}



$body = ConvertTo-Json -InputObject $VNETID1 
$header = @{ message="dogBOB"}

$response = Invoke-WebRequest -Method Post -Uri $uri -Body $body -ContentType 'application/json'  -header $header -UseBasicParsing


$jobid = (ConvertFrom-Json ($response.Content)).jobids[0]

{"WebhookName":"vnet-peer-test1","RequestBody":"{\r\n \"VNETID2\": \"/subscriptions/fea6590d-874f-42d4-a36d-4513ef125012/resourceGroups/BobRG1/providers/Microsoft.Network/virtualNetworks/VNET-test-2\"\r\n}","RequestHeader":{"Connection":"Keep-Alive","Host":"s12events.azure-automation.net","User-Agent":"Mozilla/5.0","message":"dogBOB","x-ms-request-id":"a6d35f9c-acd4-4179-a7bb-d3238022c403"}}