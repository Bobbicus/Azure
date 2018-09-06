#https://www.verboon.info/2014/04/managing-windows-defender-system-center-endpoint-security-with-powershell/

Get-command -Module MpProvider

#If no cmdlets are returned try first loading the module using the following command
Import-Module “$env:ProgramFiles\Microsoft Security Client\MpProvider”

#Get current status of system center endpoint protection
Get-MProtComputerStatus

#Check if Enpoint protect has been updated

Get-MProtComputerStatus | select RealTimeProtectionEnabled,NISSignatureLastUpdated,AntispywareSignatureLastUpdated,AntivirusSignatureLastUpdated


#list current threat files and quarantined items
Get-MProtThreat | select Resources,DidThreatExecute,IsActive,ThreatName | fl

<#
Example Output:


ThreatName       : Virus:DOS/EICAR_Test_File
Resources        : {file:_F:\DFS\Documents\2018\1\eicar1_EYDEMO006_34a3.jpeg,
                   file:_F:\DFS\Documents\2018\1\eicar_EYDEMO006_7745.jpeg,
                   file:_F:\DFS\Documents\2018\1\eicar_EYDEMO006_f4b3.jpeg}
DidThreatExecute : False
IsActive         : False

#>

