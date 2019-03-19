<#
    .SYNOPSIS
    Runs analysis for why an Azure Virtual Machine restarted.
    
    .DESCRIPTION
    Full description: Checks for the most common causes of Azure VM unexpected shutdown events.
                
    .EXAMPLE 
    Full command: Resolve-AllServicesAlert
   
   .OUTPUT
   
       Possible reason(s) for reboot of VM: oh-jump
    ---------------------------------------------------------------
    No Reason Found - Check full report below:


    Full 'Unexpected Shutdown' Report  : oh-jump         
    ---------------------------------------------------------------

    General:
    ---------------------------------------------------------------
    Virtual Machine  : VM1
    Operating System : Microsoft Windows Server 2012 R2 Datacenter
    IPv4 IP Address  : 172.16.195.20
    Last Reboot Time : 11/20/2017 10:00:06
    Server Up Time   : 11/20/2017 10:00:06

    Bluescreens (Last 3 days):
    - No BlueScreen events have been found in event log since 11/20/2017 09:35:32


    Restart Event Logs (Last 10):
    - No Reboot Events Found in Event log since 11/20/2017 09:35:36


    Installed Hot Fixes (Last 10):
    - Server was not patched between now and 11/20/2017 09:35:37
    
   

    .NOTES
    Last Updated: 13-OCT-2017
    Minimum OS: 2008 R2
    Minimum PoSh: 2.0

    Version Table:
    Version :: Author         :: Live Date   :: JIRA     :: QC             :: Description
    -----------------------------------------------------------------------------------------------------------
#>
    #Script Uri
    Param(
    [Parameter(Mandatory=$false)]$PayloadUri
    )
    #>    
    
    
    #Ingest the payload (Production)
    $object = Invoke-RestMethod -Uri $PayloadUri

    #uncomment for test payload
    #$object = ConvertFrom-Json "$(get-content -Path C:\Users\oliv8274\Desktop\payload\shutdown.json)"

    #Set Payload variables
    $ResourceId = $object.ResourceId
    #endregion

    #Ticket Signature
    $ticketSignature = "Kind regards,`n`n"


Function Resolve-AllServicesAlert {
Try{

    [Array]$Global:RestartReason = $null

    #Support functions
    Function ConvertTo-ASCII{
        <#
    .Synopsis
       Outputs the content of the PSO or array of PSO's in an a text table.
    .DESCRIPTION
       Outputs the content of the PSO or array of PSO's in an a text table.
       Only works when PSO contains NoteProperties, specify when creating PSO.
    .EXAMPLE
       Get-ASCIITable -PSOArray $Data -AddLines -List
    .NOTES
       Author = Mark Wichall.
    #>
       Param
        (
            [Parameter(Mandatory=$true)][Array]$Data, #Array or PSO's or PSO.
            [Parameter()][Switch]$AddLines, #Adds lines between pso's in table.
            [Parameter()][Switch]$Clip, #Outputs to clipboard.
            [Parameter()][Switch]$NoReturn, #if true doesn't return output
            [Parameter()][Switch]$List, #Formats output in a list
            [Parameter()][Switch]$NoAddBlankLine #Doesn't automatically add a blank line before table to fix formating with clip or copy and paste. 
        )

        Try
        {
            If ($List)
            {
                ########
                # List # (None List format, creates table with collmun headers at the top, data below.)
                ########

                #Generates a PSO containing the max length of collmns in a PSO. 
                Try
                {
                    $ContentSizePSO = New-Object PSObject
                    
                    #Gets the collumn headers from the PSO 
                    $ColNames = $Data | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name

                    #Predefining types as string so .length counts the string length
                    [String]$NameString = $null

                    $maxline = 0

                    #Loops through collumn names, checks the max size for each.
                    Foreach ($ColName in $ColNames)
                    {  
                        #length of collumn name
                        $NameString = $($ColName.Name)
                        
                        #makes sure content is a string
                        $CharNumber = $($NameString.length)

                        If ($CharNumber -gt $maxLine) 
                        {
                            $maxLine = $CharNumber
                        }
                        
                        Add-Member -InputObject $ContentSizePSO -MemberType NoteProperty -Name "CollmunHeader" -Value "$maxLine" -force -ErrorAction SilentlyContinue
                    }

                    #Predefining types as string so .length counts the string length
                    [String]$CollString = $null
                    [int]$RowCount = 0
                    [int]$CharNumber = 0

                    #Loops throught each value in collmun one for each PSO and check size.
                    Foreach ($DataPSO in $Data)
                    {                       
                        $maxline = 0
                        Foreach ($ColName in $ColNames)
                        {

                            $CollString = $DataPSO.$($ColName.Name)

                            $CharNumber = $($CollString.length)

                            If ($CharNumber -gt $maxLine) 
                            {
                                $maxLine = $CharNumber
                            }

                            #Debugging
                            #Write-Host "$($DataPSO.$($ColName.Name)) | $($CollString.length) | Max:$maxLine" -ForegroundColor Cyan
                        }

                        Add-Member -InputObject $ContentSizePSO -MemberType NoteProperty -Name "RowNumber$($RowCount)" -Value "$maxLine" -force -ErrorAction SilentlyContinue
                        $RowCount++
                    }

                }
                Catch 
                {
                    Return "Error: Could not inventory PSO or Array of PSO's"
                }

                #Gets Collmun names in Data PSO, for noteproperty's
                $ColNames = $Data | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name

                If (($ColNames | Measure-Object).count -eq 0)
                {
                    Return "Error: PSO contains no properties of type NoteProperty"
                    Break
                }

                #Gets Collum names in Content Size PSO e.g. size of the data in the Data PSO
                $ContentSizeNames = $ContentSizePSO | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name

                If (($ColNames | Measure-Object).count -eq 0)
                {
                    Return "Error: Error retriving collmun names in PSO."
                    Break
                }

                #Total row length for table
                [int]$TotalColSize = 0
                Foreach ($SizeName in $ContentSizeNames)
                {
                    If ($TotalColSize -eq 0)
                    {
                        #First collumn + 2 e.g. for "| "
                        $TotalColSize = $TotalColSize + 2
                    }
                    Else
                    {
                        #Middle collumns  + 3 e.g. for " | "
                        $TotalColSize = $TotalColSize + 3
                    }

                    #Adding max size 
                    $TotalColSize = $TotalColSize + $ContentSizePSO.($SizeName.Name)  
                }

                #Last collumns + 2 e.g. for " |"
                $TotalColSize = $TotalColSize + 2

                #Draw top line of table
                [Array]$TempStringTable = $null #table of strings
                [String]$TempStringLine = $Null #line of table

                If (-Not $NoAddBlankLine)
                {
                    #Adds blank line at start for fixing cut and paste alignment.
                    $TempStringTable = $TempStringTable = " "
                }

                $TempStringLine = $TempStringLine + " +"
                
                Foreach ($SizeName in $ContentSizeNames)
                {       
                    $ColMaxSize = $($ContentSizePSO.($SizeName.Name))      

                    $TempStringLine = $TempStringLine + ("-" + ("-" * $ColMaxSize) + "-")
        
                    $TempStringLine = $TempStringLine + "+"

                    [String]$StringLineRow = $TempStringLine
                }
                $TempStringTable = $TempStringTable + $StringLineRow

                #Draw each line in table
                [String]$ColContent = $null
                
                #Rows in table e.g. Name1,Name2,Name3...
                ForEach ($ColName in $ColNames)
                { 
                    [int]$ArraysPos = -1
                    $TempStringLine = $Null
                    $TempStringLine = $TempStringLine + " | "
                    
                    #Write-Host "New Line" -cyan

                    #Collmuns in table e.g. Name,Data,Data,Data...
                    ForEach ($ContentSizeName in $ContentSizeNames)
                    {   
                        $ColMaxSize = $($ContentSizePSO.$($ContentSizeName.Name))

                        If ($ArraysPos -lt 0)
                        {
                            #Header row
                            $ColContent = $($ColName.Name)
                        }
                        Else
                        {
                            #Collmun Data
                            $ColContent = $Data[$ArraysPos].$($ColName.Name)
                        }
                        
                        $ColContentLength = $ColContent.length                  
                        $ColPadding = $ColMaxSize - $ColContentLength

                        If ($ColPadding -gt 0)
                        {
                            $TempStringLine = $TempStringLine + $ColContent + $(" " * $ColPadding )
                        }
                        Else
                        {
                            $TempStringLine = $TempStringLine + $ColContent
                        }
                        
                        If ($ArraysPos -lt 0)
                        {
                            $TempStringLine = $TempStringLine + " = "
                        }
                        Else
                        {
                            $TempStringLine = $TempStringLine + " | "
                        }

                        $ArraysPos++

                        #Write-Debug "Ass2"
                    }

                    $TempStringTable = $TempStringTable + $TempStringLine

                    If ($AddLines)
                    {
                        #Line after every PSO in table
                        $TempStringTable = $TempStringTable + $StringLineRow
                    }
                }

                If (-Not $AddLines)
                {
                    #Bottom line of the table
                    $TempStringTable = $TempStringTable + $StringLineRow
                }
            }
            Else
            {
                ############
                # Standard # (None List format, creates table with collmun headers at the top, data below.)
                ############

                #Generates a PSO containing the max length of collmns in a PSO. 
                Try
                {
                    $ContentSizePSO = New-Object PSObject
                    
                    #Gets the collumn headers from the PSO 
                    $ColNames = $Data | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name

                    #Predefining types as string so .length counts the string length
                    [String]$NameString = $null
                    [String]$ContentString = $null

                    $maxline = 0

                    #Loops through collumn names
                    Foreach ($ColName in $ColNames)
                    {
                        #length of collumn name
                        $NameString = $($ColName.Name)
                        $maxline = $NameString.length
               
                        #max length of content of collumn        
                        Foreach ($item in $Data)
                        {
                            #makes sure content is a string
                            $ContentString = $($item.$NameString)
                            $CharNumber = $($ContentString.length)
            
                            #Debugging info
                            #Write-Host "$item" -ForegroundColor Green -NoNewline
                            #Write-Host " $CharNumber" -ForegroundColor Cyan
        
                            If ($CharNumber -gt $maxLine) 
                            {
                                $maxLine = $CharNumber
                            }
                        }
                        Add-Member -InputObject $ContentSizePSO -MemberType NoteProperty -Name "$($ColName.Name)" -Value "$maxLine" -force -ErrorAction SilentlyContinue
                    }
                }
                Catch 
                {
                    Return "Error: Could not inventory PSO or Array of PSO's"
                }
        
                #Gets Collmun names in Data PSO, for noteproperty's
                $ColNames = $Data | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name
    
                If (($ColNames | Measure-Object).count -eq 0)
                {
                    Return "Error: PSO contains no properties of type NoteProperty"
                    Break
                }

                #Gets Collum names in Content Size PSO e.g. size of the data in the Data PSO
                $ContentSizeNames = $ContentSizePSO | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name
        
                If (($ColNames | Measure-Object).count -eq 0)
                {
                    Return "Error: Error retriving collmun names in PSO."
                    Break
                }

                #Total row length for table
                [int]$TotalColSize = 0
                Foreach ($SizeName in $ContentSizeNames)
                {
                    If ($TotalColSize -eq 0)
                    {
                        #First collumn + 2 e.g. for "| "
                        $TotalColSize = $TotalColSize + 2
                    }
                    Else
                    {
                        #Middle collumns  + 3 e.g. for " | "
                        $TotalColSize = $TotalColSize + 3
                    }

                    #Adding max size 
                    $TotalColSize = $TotalColSize + $ContentSizePSO.($SizeName.Name)  
                }

                #Last collumns + 2 e.g. for " |"
                $TotalColSize = $TotalColSize + 2

                [Array]$TempStringTable = $null #table of strings
                [String]$TempStringLine = $Null #line of table

                If (-Not $NoAddBlankLine)
                {
                    #Adds blank line at start for fixing cut and paste alignment.
                    $TempStringTable = $TempStringTable = " "
                }

                $TempStringLine = $TempStringLine + " +"
                
                Foreach ($SizeName in $ContentSizeNames)
                {       
                    $ColMaxSize = $($ContentSizePSO.($SizeName.Name))      

                    $TempStringLine = $TempStringLine + ("-" + ("-" * $ColMaxSize) + "-")
        
                    $TempStringLine = $TempStringLine + "+"

                    [String]$StringLineRow = $TempStringLine
                }
                $TempStringTable = $TempStringTable + $StringLineRow

                #Header Row of table
                [String]$TempStringLine = $Null
                $TempStringLine = $TempStringLine + " | "
                
                Foreach ($SizeName in $ContentSizeNames)
                {       
                    $ColName = ($SizeName.Name)
                    $ColMaxSize = $($ContentSizePSO.($SizeName.Name))
                    $ColContentLength = $ColName.length

                    $ColPadding = $ColMaxSize - $ColContentLength

                    If ($ColPadding -gt 0)
                    {
                        $TempStringLine = $TempStringLine + $ColName + $(" " * $ColPadding )
                    }
                    Else
                    {
                        $TempStringLine = $TempStringLine + $ColName
                    }

                    $TempStringLine = $TempStringLine + " | "
                }
                $TempStringTable = $TempStringTable + $TempStringLine
    
                #Line below header in table
                $TempStringTable = $TempStringTable + (" |" + ("=" * $($TotalColSize - 2)) + "|")

                [String]$ColContent = $null

                #Content of table e.g. the data rows
                ForEach ($PSO in $Data)
                {
                    [String]$TempStringLine = $Null
                    $TempStringLine = $TempStringLine + " | "

                    Foreach ($SizeName in $ContentSizeNames)   
                    {       

                        $ColName = ($SizeName.Name)
                        $ColMaxSize = $($ContentSizePSO.($SizeName.Name))
                        $ColContent = $($PSO.($ColName))
                        $ColContentLength = $ColContent.length

                        $ColPadding = $ColMaxSize - $ColContentLength

                        If ($ColPadding -gt 0)
                        {
                            $TempStringLine = $TempStringLine + $ColContent + $(" " * $ColPadding )
                        }
                        Else
                        {
                            $TempStringLine = $TempStringLine + $ColContent
                        }

                        $TempStringLine = $TempStringLine + " | "
                    }
                    $TempStringTable = $TempStringTable + $TempStringLine

                    If ($AddLines)
                    {
                        #Line after every PSO in table
                        $TempStringTable = $TempStringTable + $StringLineRow
                    }
                }

                If (-Not $AddLines)
                {
                    #Bottom line of the table
                    $TempStringTable = $TempStringTable + $StringLineRow
                }
            }
            
            #Output to clipboard
            If ($Clip)
            {
                $TempStringTable | Clip
            }

            #Return output data from function
            If (-NOT $NoReturn)
            {
                Return $TempStringTable
            }

        }
        Catch
        {
            Return "Error Converting PSO/Array of PSO's to ASCII table"
        }
    }
   
    Function Get-BootTime{
        Try{
            #Get boot time
            Return (([datetime]::Now - (New-TimeSpan -Seconds (Get-WmiObject Win32_PerfFormattedData_PerfOS_System).SystemUptime)))
        }
        Catch
        {
            Return "Unknown error"
        }
    }

    Function Get-Uptime{
        Try{
            #Get uptime
            $lastboot = (Get-WmiObject -Class Win32_OperatingSystem).LastBootUpTime
            $Uptime = (get-date) - [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboot) | Select Days,Hours,Minutes
            
            #PSO
            $Result = New-Object PSObject -Property @{  
            	    Uptime = "Days=$($Uptime.Days) Hours=$($Uptime.Hours) Mins=$($Uptime.Minutes)";
                    UptimeDays = ($Uptime.Days);
                    }
            
            Return $Result
        }
        Catch
        {     
            $Result = New-Object PSObject -Property @{  
            	    Uptime = "Unknown error";
                    UptimeDays = "Unknown error";
                    }
            
            Return $Result
        }
    }

    Function Get-BlueScreens{
        Param(
        [Parameter()]$UptimeDays
    )
        Try{
            If ($UptimeDays -gt 3)
            {
                #Rebooted more that 3 days ago.
                $bluescreen = "- Server rebooted more than 3 days ago.  Skipping Check." 

                #$bluescreen = Get-EventLog -LogName application -Newest 100 -Source 'Windows Error*' |
                #select timewritten, message | where message -match 'bluescreen' |  format-table -auto -wrap
            }
            Else
            {
                $bluescreenEvent = Get-EventLog -ErrorAction SilentlyContinue -LogName Application -After $((Get-Date).AddDays(-(1 + $UptimeDays))) -Source 'Windows Error*' |
                select timewritten, message -ErrorAction SilentlyContinue;

                If (($bluescreenEvent | Measure-Object).Count -gt 0)
                {
                    $bluescreenCheck = $bluescreenEvent | where message -match 'bluescreen' -ErrorAction SilentlyContinue | 
                    Select-Object -First 5 -ErrorAction SilentlyContinue;
                }
                
                If (($bluescreenCheck | Measure-Object).Count -gt 0)
                {
                    $RecTemp = New-Object PSObject -Property @{             
                    "Reason" =  "Server has suffered a bluescreen event; see details below:";  
                    }
                    $Global:RestartReason += $RecTemp

                    $bluescreen = $bluescreenCheck | format-table -auto -wrap -ErrorAction SilentlyContinue | Out-String;      
                }
                Else
                {
                    $bluescreen = "- No BlueScreen events have been found in event log since $((Get-Date).AddDays(-(1 + $UptimeDays)))"
                }
            }
            
            Return $bluescreen
        }
        Catch
        {
            Return "Unknown error"
        }
    }

    Function Get-Last10HotFixs{
    Param(
    [Parameter()]$UptimeDays
    )
        Try{
            If ($UptimeDays -gt 3)
            {
                #Rebooted more that 3 days ago.
                $Last10Hotfixes = "- Server rebooted more than 3 days ago.  Skipping Check." 

                #$Hotfixes = Get-HotFix -ErrorAction SilentlyContinue | Select-Object -ErrorAction SilentlyContinue PSComputerName,HotfixID,Description,InstalledBy,@{label="InstalledOn";e={[DateTime]::Parse($_.psbase.properties["installedon"].value,$([System.Globalization.CultureInfo]::GetCultureInfo("en-US")))}}
                #$Last5Hotfixes = $Hotfixes | Sort-Object InstalledOn -ErrorAction SilentlyContinue  | Select-Object -Last 5 -ErrorAction SilentlyContinue 
            }
            Else
            {
                $Hotfixes = Get-HotFix -ErrorAction SilentlyContinue | Where-object {$_.InstalledOn -gt $((Get-Date).AddDays(-(1 + $UptimeDays)))};
                
                If (($Hotfixes | Measure-Object).Count -gt 0)
                {
                    $HotfixesSorted = $Hotfixes | Select-Object -ErrorAction SilentlyContinue HotfixID,Description,InstalledBy,@{label="InstalledOn";e={[DateTime]::Parse($_.psbase.properties["installedon"].value,$([System.Globalization.CultureInfo]::GetCultureInfo("en-US")))}} | Sort-Object InstalledOn -ErrorAction SilentlyContinue;
                                        
                    $RecTemp = New-Object PSObject -Property @{             
                    "Reason" =  "Windows Updates have recently been installed.";
                    }

                    $Global:RestartReason += $RecTemp
                    $Last10Hotfixes = $HotfixesSorted | Select-Object -Last 10 -ErrorAction SilentlyContinue;
                
                    If (($Last10Hotfixes | Measure-Object).Count -gt 0)
                    {
                        $Last10Hotfixes = ConvertTo-ASCII -Data $Last10Hotfixes
                    }
                    Else
                    {
                        $Last10Hotfixes = "Error retreiving results. "
                    }
                }
                Else
                {
                    $Last10Hotfixes = "- Server was not patched between now and $((Get-Date).AddDays(-(1 + $UptimeDays)))"
                }
            }

            Return $Last10Hotfixes
        }
        Catch
        {
            Return "Unknown error2"
        }
    }

    Function Get-Reboots{
        Param(
        [Parameter()]$UptimeDays
    )
        Try{
            If ($UptimeDays -gt 3)
            {
                #Rebooted more that 3 days ago.
	            $RestartInfo = "- Server rebooted more than 3 days ago.  Skipping Check.";

                #$RestartEvents = Get-EventLog -logname System |where-object {$_.eventid -eq 1074 -or $_.eventid -eq "41"} | 
                #Sort-Object Index -Descending | Select-Object -First 5            
            }
            Else
            {
                $RestartEvents = Get-EventLog -LogName System -After $((Get-Date).AddDays(-(1 + $UptimeDays))) -ErrorAction SilentlyContinue | where-object {$_.eventid -eq 1074 -or $_.eventid -eq "41"} -ErrorAction SilentlyContinue | Sort-Object Index -Descending -ErrorAction SilentlyContinue| Select-Object -First 5 -ErrorAction SilentlyContinue;
                #or $_.eventid -eq "6008" is event log shutdown but 41 is always logged with 6008 from what i can tell
            
                If (($RestartEvents | Measure-Object).Count -gt 0)
                {
                    [Array]$Restarts = $null;
                    ForEach ($Event in $RestartEvents)
                    {
                        $Message = $Event.Message
                        $RestartUser = $Event.Message

                        If($Event.eventid -eq 1074)
                        {
                            $Reason = "User initiated"
                            #Get the username
                            $UsernameRaw = $null
                            $Username = $null
                            [regex]$regex = "user (.*) for"
                            $UsernameRaw = $regex.Matches($Message) | foreach-object {$_.Value};
                        
                            If(-NOT $usernameraw)
                            {
                                $Username = "Could not parse"
                            }
                            Else
                            {
                                $Username = $usernameraw.split(" ")[1]
                            }
                        }
                        Else
                        {
                            $Reason = "System error"
                            $Username = "Not applicable"
                        }

                        $TempOutput = New-Object PSObject -Property @{   
                            Time = $Event.TimeGenerated;
                            Message = $Event.Message;
                            Reason = $Reason;
                            "Initiating User" = $Username;
                        }

                        [Array]$Restarts += $TempOutput
                    }

                    If (($Restarts | Measure-Object).Count -gt 0)
                    {
                        if($RestartEvents.eventid -contains 1074)
                        {
                            $RecTemp = New-Object PSObject -Property @{             
                                "Reason" =  "Server had a User initiated restart. See details below:";
                            }   
                        }
                        else
                        {
                           $RecTemp = New-Object PSObject -Property @{             
                                "Reason" =  "Azure VM was probably redeployed to a new Hypervisor.";
                            }    
                        }

                        $Global:RestartReason += $RecTemp

                        #ignoring message as converto-ascii doesnt support multi line
                        $RestartInfo = ConvertTo-ASCII -Data ($Restarts | Select-Object Time,Reason,"Initiating User" )   
                    }
                    Else
                    {
                        $RestartInfo = "- No Reboot Events Found in Event log since $((Get-Date).AddDays(-(1 + $UptimeDays)))"
                    }

                }
                Else
                {
                    $RestartInfo = "- No Reboot Events Found in Event log since $((Get-Date).AddDays(-(1 + $UptimeDays)))"
                }
            }
           Return $RestartInfo
        }
        Catch
        {  
           Return "Unknown error";
        }
    }

    Function Test-RegistryValue {

        param (

         [parameter(Mandatory=$true)]
         [ValidateNotNullOrEmpty()]$Path,

        [parameter(Mandatory=$true)]
         [ValidateNotNullOrEmpty()]$Value
        )

            try
            {
                Get-ItemProperty -Path $Path -Name $Value -ErrorAction Stop | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
                return $true
            }

            catch 
            {
                return $false
            }

    }

    #output psobject
    $Output = New-Object PSObject -Property @{
        "Boot Time" = "Not Found";
        "Up Time" = "Not Found";
        "Restart Events" = "Not Found";
        "Last 10 Hotfixes" = "Not Found";
        "Bluescreen" = "Not Found";
    }

    #Boottime
    $Output."Boot Time" = Get-BootTime

    #UpTime
    $Results = Get-Uptime
    $Output."Up Time" = ($Results.Uptime)

    #Look for bluescreens
    $Output."Bluescreen" = Get-BlueScreens -UptimeDays $($Results.UptimeDays)

    #Look for restart events
    $Output."Restart Events" = Get-Reboots -UptimeDays $($Results.UptimeDays)

    #Looks for last 10 hotfixes installed
    $Output."Last 10 Hotfixes" = Get-Last10HotFixs -UptimeDays $($Results.UptimeDays)
    
    #OS and IP variables
    $OSType = (Get-CimInstance Win32_OperatingSystem).Caption
    $LocalIpAddress = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
       
    if(-not $Global:RestartReason){
        $Global:RestartReason = "No Reason Found - Check full report below:"
    }

    #Generate a pretty output for the ticket
    $OutputReport = @()
    $OutputReport += "Possible reason(s) for reboot of VM: $env:computername"
    $OutputReport += "---------------------------------------------------------------"
    $OutputReport += "$($Global:RestartReason.Reason | out-string)"
    $OutputReport += ""
    $OutputReport += "Smart Ticket Automation 'Unexpected Shutdown' Report : $ENV:ComputerName         "
    $OutputReport += "---------------------------------------------------------------"
    $OutputReport += "Virtual Machine  : $env:computername"
    $OutputReport += "Operating System : $OSType"
    $OutputReport += "IPv4 IP Address  : $LocalIpAddress"  
    $OutputReport += "Last Reboot Time : $($Output."Boot Time")"
    $OutputReport += "Server Up Time   : $($Output."Up Time")"
    $OutputReport += ""
    $OutputReport += "Bluescreens (Last 3 days):"
    $OutputReport += $($output."Bluescreen" | out-string)
    $OutputReport += ""
    $OutputReport += "Restart Event Logs (Last 10):"
    $OutputReport += $($output."Restart Events" | out-string)
    $OutputReport += ""
    $OutputReport += "Installed Hot Fixes (Last 10):"
    $OutputReport += $($output."Last 10 Hotfixes" | out-string)
    if ($($Global:RestartReason.Reason) -eq "Azure VM was probably redeployed to a new Hypervisor.")
    {
        $OutputReport += "Guest OS checks complete. Smart Ticket automation will retrieve the VM's power state and recent health events to confirm that the VM was recently redeployed to a new Hypervisor, another update will follow shortly.`n`n"
        $OutputReport += "$($ticketSignature)"    

    }
    elseif ($($Global:RestartReason.Reason) -eq "Windows Updates have recently been installed.")
    {
        $OutputReport += "Guest OS checks complete. Smart Ticket automation has confirmed that this VM was rebooted after Windows Updates were recently installed. If you have any questions, please let us know, otherwise this ticket will close automatically.`n`n"
        $OutputReport += "$($ticketSignature)"    

    }
    else
    {
    }
    #escape any backslash so BBcode does not parse it as new lines etc
    #the double \ in the first entry is because its regex so we need to escape the slash as a literal character
    $OutputReport =  $OutputReport -Replace("\\","\\")

    $temp = New-Object PSObject -Property @{
        Server = $ENV:ComputerName
        Report = ($OutputReport | Out-String)
    }
    return $temp
       
    }
    catch
    {
        #error exception
        Return $_
    }
}

(Resolve-AllServicesAlert).Report | Format-List