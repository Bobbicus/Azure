
 
# Authenticate
 
#Sign in with Service Principal ID
 
$passwd = ConvertTo-SecureString "ABCDefghiJKLMN1234mnbzxcvqwe" -AsPlainText -Force
 
$pscredential = New-Object System.Management.Automation.PSCredential('ABCDe-fghiJKL-MN1234mnb-zxcvqwe', $passwd)
 
# you should use Get-Credential in place of above two line to keep password secure
 
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant 123abc123-abcd-123abc123
 
#Set the MPN ID to current user Account
Get-AzManagementPartner

new-AzManagementPartner -PartnerId 1235456