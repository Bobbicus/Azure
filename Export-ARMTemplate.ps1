$RGName = ""
$Path = ""
$subscrptionid = ""

set-azurermcontext -Subscription $subscrptionid

Export-AzureRmResourceGroup -ResourceGroupName $RGName -IncludeParameterDefaultValue -path $Path