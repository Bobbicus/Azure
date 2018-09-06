#https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-configure-ssl-policy-powershell#update-an-existing-application-gateway-with-a-pre-defined-ssl-policy
#Auth to the cusotmers subscripton

#Switch Context to correct subscription
Set-AzureRMContext -Subscription "1234435435645645erwgtr5435435efr"

#################################
# Update DR AppGW
#################################

# You have to change these parameters to match your environment.
$AppGWname = "DR-AGW-WEB-1"
$RG = "WEU-RSG-WEB-DR"

$AppGw = get-azurermapplicationgateway -Name $AppGWname -ResourceGroupName $RG

#Run this command to see available policies
Get-AzureRMApplicationGatewayAvailableSslOptions


#Review output to see that before the change SSLpolicy is blank
$AppGw
# SSL Predefined Policy AppGwSslPolicy20170401S
Set-AzureRmApplicationGatewaySslPolicy -PolicyType Predefined -PolicyName "AppGwSslPolicy20170401S" -ApplicationGateway $AppGW

# Update AppGW
# The SSL policy options are not validated or updated on the Application Gateway until this cmdlet is executed.
$SetGW = Set-AzureRmApplicationGateway -ApplicationGateway $AppGW

#Check application gateway policy has been get config again
$AppGw = get-azurermapplicationgateway -Name $AppGWname -ResourceGroupName $RG

#Review output check SSLpolicy field for new policy "AppGwSslPolicy20170401S"
$AppGw




#################################
#RollBackplan 
#################################

<#if the new policy breaks anything we can change back the default policy uisng the following
##DR
Set-AzureRmApplicationGatewaySslPolicy -PolicyType Predefined -PolicyName "AppGwSslPolicy20150501" -ApplicationGateway $AppGW

##PROD
Set-AzureRmApplicationGatewaySslPolicy -PolicyType Predefined -PolicyName "AppGwSslPolicy20150501" -ApplicationGateway $AppGwPrd

#>
 