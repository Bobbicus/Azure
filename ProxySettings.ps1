<#https://msdn.microsoft.com/en-us/library/ms815135.aspx
Change Gropup policy - we can do this locally unless the customer has AD wide settings. 
Under this setting:  Computer Configuration\Administrative Templates\Windows Components\Internet Explorer 
Enable "Make proxy settings per-machine (rather than per user)"
#>

https://social.technet.microsoft.com/Forums/windows/en-US/7d420c66-2e89-43d7-b136-baf5f69690f1/locking-down-ie-proxy-settings-under-pc-settingsnetworkproxy-on-windows-81?forum=w8itprosecurity

The first thing we need to do is to export the following registry key from a machine that has the correct proxy settings set.

HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections

This contains the following 2 binary registry keys which have the connections settings: “DefaultConnectionSettings” and “SavedLegacySettings”

The next step is to open the newly exported .reg file and to change the path:

From: HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections


HKLM\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings

ProxySettingsPerUser

Dword

Value=0

We have the following values:

0 -> policy set at machine level.

1 -> policy set at user level. 

$DefaultConnectionSettings = "46,00,00,00,06,00,00,00,0b,00,00,00,11,00,00,00,31,30,2e,31,32,30,2e,30,2e,31,34,38,3a,33,31,32,38,1e,00,00,00,6f,67,62,2e,69,6e,74,65,72,6e,61,6c,2e,6f,78,66,61,6d,2e,6e,65,74,3b,3c,6c,6f,63,61,6c,3e,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00"

$SavedLegacySettings = "46,00,00,00,0a,00,00,00,0b,00,00,00,11,00,00,00,31,30,2e,31,32,30,2e,30,2e,31,34,38,3a,33,31,32,38,1e,00,00,00,6f,67,62,2e,69,6e,74,65,72,6e,61,6c,2e,6f,78,66,61,6d,2e,6e,65,74,3b,3c,6c,6f,63,61,6c,3e,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00"
$hexified = $DefaultConnectionSettings.Split(',') | % { "0x$_"}

$hexified2 = $SavedLegacySettings.Split(',') | % { "0x$_"}
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name DefaultConnectionSettings -PropertyType Binary -Value ([byte[]]$hexified) -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name SavedLegacySettings -PropertyType Binary -Value  ([byte[]]$hexified2) -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyOverride -PropertyType string -Value  "localsite.com;<local>" -force
New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxySettingsPerUser -PropertyType Dword -Value  1 -force

#New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Internet Explorer\Control Panel" -Name "Proxy"  -PropertyType Dword -Value   1  -force
#New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Internet Explorer\Control Panel" -Name "AutoConfig"  -PropertyType Dword -Value  1  -force

New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "WarnOnIntranet"  -PropertyType Dword -Value  0  -force
New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable"  -PropertyType Dword -Value 1  -force
New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "MigrateProxy"  -PropertyType Dword -Value  1  -force
New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer"  -PropertyType string -Value  10.120.0.148:3128  -force
New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride"  -PropertyType string -Value  "localsite.com;<local>" -force

New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxySettingsPerUser"  -PropertyType Dword -Value 0  -force