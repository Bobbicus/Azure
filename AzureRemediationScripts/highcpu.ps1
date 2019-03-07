<#
    .SYNOPSIS
    Runs analysis of CPU Usage for Azure Smart Tickets.
       
    .DESCRIPTION
    Checks for causes of high CPU usage.
    Supported: Yes
    Prerequisites: No
    Makes changes: No

    .EXAMPLE
    Full command: Resolve-CpuAlerts | Select-object Report | Format-List

    Output: Output Table 
       
    .OUTPUTS
          Process Details: 
          +-------------+----------------+------+
          | ProcessName | %ProcessorTime | PID  | 
          |=====================================|
          | calc        | 10             | 4208 | 
          | services    | 6              | 572  | 
          | smss        | 2              | 320  | 
          | spoolsv     | 2              | 1200 | 
          | svchost     | 0              | 804  | 
          +-------------+----------------+------+

          Additional Items Reported:
          - Uptime
          - Server Connections
          - Running Processes
          - Common Services Running
        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0

    Version Table:
    Version :: Author         :: Live Date   :: JIRA     :: QC             :: Description
    -----------------------------------------------------------------------------------------------------------
#>

Function Resolve-CpuAlerts {
Try{

    [Array]$Global:Reason = $null

    #Use this variable to set the threshold so that different ticket updates get activated
    $cpuThreshold = '75'

    #Signature variable
    $ticketSignature = "Kind regards,`n`n"

    #region ascii
    #####################
    # Support functions #
    #####################
    <#
    .Synopsis
       Outputs the content of the PSO or array of PSO's in an a text table.
    .DESCRIPTION
       Outputs the content of the PSO or array of PSO's in an a text table.
       Only works when PSO contains NoteProperties, specify when creating PSO.
    .EXAMPLE
       Get-ASCIITable -PSOArray $Data -AddLines -List
    .NOTES
    #>
    Function ConvertTo-ASCII{
            Param
            (
                [Parameter(Mandatory=$true)][Array]$Data, #Array or PSO's or PSO.
                [Parameter()][Switch]$AddLines, #Adds lines between pso's in table.
                [Parameter()][Switch]$Clip, #Outputs to clipboard.
                [Parameter()][Switch]$NoReturn, #if true doesn't return output
                [Parameter()][Switch]$List, #Formats output in a list
                [Parameter()][Switch]$NoAddBlankLine, #Doesn't automatically add a blank line before table to fix formating with clip or copy and paste. 
                [Parameter()][Switch]$SortDescending, #Sorts Collmuns in Descending order.
                [Parameter()][String]$SortNameSwitch #Sorts the string value Collmun to be first in the table
            )

            Try
            {           
                #Initialize PSO
                $ContentSizePSO = New-Object PSObject

                #Gets Collmun names in Data PSO, for noteproperty's
                $ColNames = $Data | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name
            
                If (($ColNames | Measure-Object).count -eq 0)
                {
                    Return "Error: `$Data PSO or Array of PSO's contains no properties of type NoteProperty"
                    Break
                }

                [Array]$SortedObject = $null

                #Converts the PSO to an Array, sorting the data as required
                If ($SortNameSwitch.Length -gt 0)
                {
                    Write-Verbose "Sort `$SortNameSwitch = `$true"
                
                    [Array]$MinusNames = $null

                    #Order Collmun names by textstring first, then other feilds
                    Foreach ($ColName in $ColNames)
                    {
                        If ($($ColName.Name) -eq $SortNameSwitch) 
                        {
                            $NameSwitch = $true
                            $SortedObject = $SortedObject + $($ColName.Name)
                        }
                        Else
                        {
                            $MinusNames = $MinusNames + $($ColName.Name)
                        }
                    }

                    If ($NameSwitch)
                    {
                        Write-Verbose "Sort `$NameSwitch = `$true"

                        #Sorts Collumn Names in Descending order
                        If ($SortDescending)
                        {
                            Write-Verbose "Sort Descending = `$true"
                            $MinusNames = $MinusNames | sort-object -Descending
                        }
                    
                        ForEach ($MinusName in $MinusNames)
                        {
                            $SortedObject = $SortedObject + $MinusName
                        }
                    
                    }
                    $ColNames = $SortedObject
                }
                Else
                {
                    Write-Verbose "Sort `$SortNameSwitch = `$false"
                    #Sorts Collumn Names in Descending order
                    If ($SortDescending)
                    {
                        Write-Verbose "Sort Descending = `$true"
                        $ColNames = $ColNames | sort-object -Descending
                    }

                    #Converts the PSO values to an Array, strips out the .name noteproperty
                    Foreach ($ColName in $ColNames)
                    {
                            $SortedObject = $SortedObject + $($ColName.Name)
                    }
                    $ColNames = $SortedObject
                }

                Write-Debug "After `$ColNames Sort"

                #Predefining types as string so .length counts the string length
                [String]$NameString = $null

                $maxline = 0

                If ($List)
                {
                    ########
                    # List # (None List format, creates table with collmun headers at the top, data below.)
                    ########

                    #Generates a PSO containing the max length of collmns in a PSO. 
                    Try
                    {                    
                        #Loops through collumn names, checks the max size for each.
                        Foreach ($ColName in $ColNames)
                        {  
                            #length of collumn name
                            $NameString = $ColName
                        
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

                                $CollString = $DataPSO.$ColName

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

                    #Gets Collum names in Content Size PSO e.g. size of the data in the Data PSO
                    #This array holds different data to $ColNames
                    $ContentSizeNames = $ContentSizePSO | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name

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

                    #Starts to Draw Table into Array (List Layout)
                    ##############################################
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
                                $ColContent = $ColName
                            }
                            Else
                            {
                                #Collmun Data
                                $ColContent = $Data[$ArraysPos].$ColName
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
                        #Predefining types as string so .length counts the string length
                        [String]$ContentString = $null

                        #Loops through collumn names
                        Foreach ($ColName in $ColNames)
                        {
                            #length of collumn name
                            $NameString = $ColName
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
                            Add-Member -InputObject $ContentSizePSO -MemberType NoteProperty -Name "$ColName" -Value "$maxLine" -force -ErrorAction SilentlyContinue
                        }
                    }
                    Catch 
                    {
                        Return "Error: Could not inventory PSO or Array of PSO's"
                    }

                    #Gets Collum names in Content Size PSO e.g. size of the data in the Data PSO
                    #$ContentSizeNames = $ContentSizePSO | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name
        
                    If (($ColNames | Measure-Object).count -eq 0)
                    {
                        Return "Error: Error retriving collmun names in Content Size PSO."
                        Break
                    }

                    #Total row length for table
                    [int]$TotalColSize = 0
                    Foreach ($ColName in $ColNames)
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
                        $TotalColSize = $TotalColSize + $ContentSizePSO.$ColName
                    }

                    #Last collumns + 2 e.g. for " |"
                    $TotalColSize = $TotalColSize + 2

                    [Array]$TempStringTable = $null #table of strings
                    [String]$TempStringLine = $Null #line of table

                    #Starts to Draw Table into Array (Standard Layout)
                    ##################################################

                    If (-Not $NoAddBlankLine)
                    {
                        #Adds blank line at start for fixing cut and paste alignment.
                        $TempStringTable = $TempStringTable = " "
                    }

                    $TempStringLine = $TempStringLine + " +"
                
                    Foreach ($ColName in $ColNames)
                    {       
                        $ColMaxSize = $($ContentSizePSO.$ColName)      

                        $TempStringLine = $TempStringLine + ("-" + ("-" * $ColMaxSize) + "-")
        
                        $TempStringLine = $TempStringLine + "+"

                        [String]$StringLineRow = $TempStringLine
                    }
                    $TempStringTable = $TempStringTable + $StringLineRow

                    #Header Row of table
                    [String]$TempStringLine = $Null
                    $TempStringLine = $TempStringLine + " | "
                
                    Foreach ($ColName in $ColNames)
                    {       
                        $ColMaxSize = $($ContentSizePSO.$ColName)
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

                        Foreach ($ColName in $ColNames)   
                        {       
                            $ColMaxSize = $($ContentSizePSO.$ColName)
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
    #endregion
 
    #WMI query to query CPU Time per process
    Function Get-ProcessDetails{
        Try{
            #Process list from WMI
            $Processes = Get-WmiObject Win32_PerfFormattedData_PerfProc_Process | `
            where-object{ $_.Name -ne "_Total" -and $_.Name -ne "Idle"} | `
            Sort-Object PercentProcessorTime -Descending | `
            Select-object Name,IDProcess,PercentProcessorTime -First 5;

            [Array]$Results = $null

            ForEach($Process in $Processes)
            {
                $ProcessPSO = New-Object PSObject -Property @{
                        "ProcessName" = $($Process.Name);
                        "PID" = $($Process.IDProcess);
                        "%ProcessorTime" = $($Process.PercentProcessorTime);
                        }

                $Results = $Results + $ProcessPSO
            }
            Return $Results
        }
        Catch
        {     
            $ProcessPSO = New-Object PSObject -Property @{  
                        "ProcessName" = "Unknown error";
                        "PID" = "Unknown error";
                        "%ProcessorTime" = "Unknown error";   
                    }
                    #"Contained Processes" = "Unknown error";

            $Results = $Results + $ProcessPSO
            Return $Results
        }
    }

    Function Get-ProcessDetails2{
        Try{
            #Process list from WMI
            $Processes2 = Get-WmiObject Win32_PerfFormattedData_PerfProc_Process | `
            where-object{ $_.Name -ne "_Total" -and $_.Name -ne "Idle"} | `
            Sort-Object PercentProcessorTime -Descending | `
            Select-object Name,IDProcess,PercentProcessorTime -First 5;

            [Array]$Results2 = $null

            ForEach($Process2 in $Processes2)
            {
                $ProcessPSO2 = New-Object PSObject -Property @{
                        "ProcessName" = $($Process2.Name);
                        "PID" = $($Process2.IDProcess);
                        "%ProcessorTime" = $($Process2.PercentProcessorTime);
                        }

                $Results2 = $Results2 + $ProcessPSO2
            }
            Return $Results2
        }
        Catch
        {     
            $ProcessPSO2 = New-Object PSObject -Property @{  
                        "ProcessName" = "Unknown error";
                        "PID" = "Unknown error";
                        "%ProcessorTime" = "Unknown error";   
                    }
                    #"Contained Processes" = "Unknown error";

            $Results2 = $Results2 + $ProcessPSO2
            Return $Results2
        }
    }

    #Display top five processes executed by a user
    Function Get-ProcessUserDetails{
        Try{
            #Process list from Powershell
            $Processes = Get-Process -IncludeUserName | `
            Sort-Object CPU -Descending | `
            Select-Object ProcessName, CPU, Username, Id -First 5;

            [Array]$Results = $null

            ForEach($Process in $Processes)
            {
                $ProcessPSO = New-Object PSObject -Property @{
                        "ProcessName" = $($Process.ProcessName);
                        "Username" = $($Process.Username);
                        "PID" = $($Process.Id);
                        "CPU Metric" = $($Process.CPU);
                        }
                $Results = $Results + $ProcessPSO
            }
            Return $Results
        }
        Catch
        {     
            $ProcessPSO = New-Object PSObject -Property @{  
                        "ProcessName" = "Unknown error";
                        "Username" = "Unknown error";
                        "PID" = "Unknown error";
                        "%ProcessorTime" = "Unknown error";   
                    }
                    
            $Results = $Results + $ProcessPSO
            Return $Results
        }
    }

    #Function to collect last Boot time.
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

    #Function to query the uptime of the VM
    Function Get-Uptime{
        Try{
            #Get uptime
            $lastboot = (Get-WmiObject -Class Win32_OperatingSystem).LastBootUpTime
            $Uptime = (get-date) - [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboot) | Select Days,Hours,Minutes
            
            #PSO
            $Result = New-Object PSObject -Property @{  
            	    "Uptime" = "Days=$($Uptime.Days) Hours=$($Uptime.Hours) Mins=$($Uptime.Minutes)";
                    "UptimeDays" = ($Uptime.Days);
                    }
            
            Return $Result
        }
        Catch
        {     
            $Result = New-Object PSObject -Property @{  
            	    "Uptime" = "Unknown error";
                    "UptimeDays" = "Unknown error";
                    }
            
            Return $Result
        }
    }

    #Function to collect all the NETSEC statistics
    Function Get-ConnectionCount{
        Try{
            #Get Netstat connections
            $netstat = netstat -ano
            $timewait = $netstat | findstr "TIME_WAIT" | Measure-Object;
            $established = $netstat | findstr "ESTABLISHED" | Measure-Object;
            $closewait = $netstat | findstr "CLOSE_WAIT" | Measure-Object;
            $Fin_Waits_2 = $netstat | findstr "FIN_WAIT_2" | Measure-Object;
            
            #PSO
            $Result = New-Object PSObject -Property @{  
                    "Established" = ($established).Count;
            	    "Time Wait" = ($timewait).Count;
                    "Close Wait" = ($closewait).Count;
                    "Fin wait 2" = ($Fin_Waits_2).Count;
                    }
            
            Return $Result
        }
        Catch
        {     
            $Result = New-Object PSObject -Property @{  
            	    "Uptime" = "Unknown error";
                    "Established" = "Unknown error";
            	    "Time Wait" = "Unknown error";
                    "Close Wait" = "Unknown error";
                    "Fin wait 2" = "Unknown error";
                    }
            
            Return $Result
        }
    }
    
    #Function to query important services and if they are present on the VM
    Function Get-CoreServices {
    Param
        (
            [Array]$CheckServices
        )

        Try
        {
            If ($($CheckServices | Measure-Object).count -gt 0)
            {
                $Services = Get-Service -ErrorAction SilentlyContinue | Select-Object Status,DisplayName,Name
                If ($($Services | Measure-Object).count -gt 0)
                {
                    $Results = New-Object PSObject
            	 
                    Foreach ($CheckService in $CheckServices)
                    {
                        [switch]$CurrentCheck = $false
                    
                        Foreach ($Service in $Services)
                        {
                            If (($Service.displayname -like "*$CheckService*") -or ($Service.name -like "*$CheckService*"))
                            {                          
                                Add-Member -InputObject $Results -MemberType NoteProperty -Name "$($Service.displayname)" -Value "Installed" -force -ErrorAction SilentlyContinue
                                $CurrentCheck = $true
                            }
                        }
                    
                        #If no matches found  
                        If (-Not $CurrentCheck)
                        {
                            Add-Member -InputObject $Results -MemberType NoteProperty -Name "$CheckService" -Value "Absent" -force -ErrorAction SilentlyContinue
                        }
                    }
                }   
            }
            Return $Results
        }       
        Catch
        {
            $Results = New-Object PSObject -Property @{"$CheckServices" = "Unknown Error"}     

            Return $Results
        }
    }
 
    #####################
    # Execute Functions #
    #####################
   
    $OSType = (Get-CimInstance Win32_OperatingSystem).Caption
    $LocalIpAddress = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
    $Connections = Get-ConnectionCount; #Connections
    
    #Boot time and up time
    #PSO - Boottime and Uptime
    $PSO = New-Object PSObject -Property @{
            "UptimeDays" = "Unknown Error";
            "Uptime" = "Unknown Error";
    	    "Boot time" = "Unknown Error";
            } 
           
    #Boottime
    $PSO."Boot Time" = Get-BootTime;

    #UpTime
    $Uptime = Get-Uptime
    $PSO."UptimeDays" = $($Uptime."UptimeDays");
    $PSO."Uptime" = $($Uptime."Uptime");
    
    #Process Details
    [Array]$ProcDetails = Get-ProcessDetails;
    [Array]$ProcUserDetails = Get-ProcessUserDetails;
    [Array]$script:ProcDetails2 = Get-ProcessDetails2;

    #Service Names to use for Installed Server Roles Output
    [Array]$CheckServices = "Active Directory Domain Services", "Cluster Service", "DNS Server", "SQL Server (MSSQLSERVER)", "World Wide Web Publishing Service";
    [Array]$Services = Get-CoreServices -CheckServices $CheckServices;


    ################
    # Build Output #
    ################

    [Array]$Output = $null

    #Check whether the CPU% counter is above 75% threshold, if so, dump diagnostics report into ticket
    if ($ProcDetails[0].'%ProcessorTime' -gt $cpuThreshold -and $ProcDetails[0].ProcessName -notlike '*sqlservr*' -and $ProcDetails[0].ProcessName -notlike '*w3wp*')
    {
    $Output = $Output + "[TICKET_UPDATE=PRIVATE]"
    $Output = $Output + "[TICKET_STATUS=ALERT RECEIVED]"
    $Output = $Output + "Hello Team,`n`nCPU Usage is still high (above $($cpuThreshold)% threshold), therefore, this alert has not cleared.`n`nPlease investigate further and review the following Diagnostics Report:`n"
    $Output = $Output + " ------------------------------------------------"
    $Output = $Output + " VM:  $env:computername"
    $Output = $Output + " OS:  $OSType"
    $Output = $Output + " IP:  $LocalIpAddress"   
    $Output = $Output + " " #add blank line

    #Boot time and up time
    $Output = $Output + " "
    $Output = $Output + "Uptime and Boottime: "
    If (($PSO | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $PSO -List -NoAddBlankLine)
    }
    Else
    {
        $Output = $Output + "Error retreiving results."
    }
    $Output = $Output + " " #add blank line          
       
    #Connections    
    $Output = $Output + " "
    $Output = $Output + "NETSTAT Connections: "
    If (($Connections | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $Connections -List -NoAddBlankLine -SortNameSwitch "Established")
    }
    Else
    {
       $Output = $Output + "Error retrieving results."
    }
    $Output = $Output + " " #add blank line      

    #Process Details
    $Output = $Output + " "
    $Output = $Output + "Process Details (Current CPU Time): "
    If (($ProcDetails | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $ProcDetails -NoAddBlankLine -SortNameSwitch "ProcessName")
    }
    Else
    {
       $Output = $Output + "Error retreiving results."
    }
    $Output = $Output + " " #add blank line

    #User Process Details
    $Output = $Output + " "
    $Output = $Output + "User Process Details (Total CPU Time): "
    If (($ProcUserDetails | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $ProcUserDetails -NoAddBlankLine)
    }
    Else
    {
       $Output = $Output + "Error retreiving results."
    }
    $Output = $Output + " " #add blank line

    #Are Core services installed and running
    $Output = $Output + " "
    $Output = $Output + "Installed Server Roles: "
    If (($Services | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $Services -List -NoAddBlankLine)
    }
    Else
    {
       $Output = $Output + "Error retreiving results."
    }
    $Output = $Output + "`n"
    $Output = $Output + "$($ticketSignature)" 
 }

    #MSSQL: Check whether CPU% counter has is above 75% and if so, update and set ticket to Confirm Solved status
    elseif ($ProcDetails[0].'%ProcessorTime' -gt $cpuThreshold -and $ProcDetails[0].ProcessName -like '*sqlservr*')
            {          
                $Output = $Output + "Hello Team,`n"
                $Output = $Output + "Microsoft SQL Server is one of the main processess using a high percentage of the VM's CPU:`n"
                $Output = $Output + "   VM:  $($env:computername)"
                $Output = $Output + "   OS:  $($OSType)"
                $Output = $Output + "   IP:  $($LocalIpAddress)`n"
                $Output = $Output + "Process Details (Top 5) - ordered by CPU%:"
                $Output = $Output + $(ConvertTo-ASCII -data $script:ProcDetails2 -NoAddBlankLine -SortNameSwitch "ProcessName")
                $Output = $Output + "`nThis can be considered normal behaviour for a MSSQL Server, therefore, please review your instance resources and let us know if you need any further assistance. This ticket will be set to Solved status and we will continue to monitor the VM for any further alerts; if you have any questions please let us know."
                $Output = $Output + "`n"
                $Output = $Output + "$($ticketSignature)"
            }
    #IIS: Check whether CPU% counter is above 75% and if so, update and set ticket to Confirm Solved status
    elseif ($ProcDetails[0].'%ProcessorTime' -gt $cpuThreshold -and $ProcDetails[0].ProcessName -like '*w3wp*')
            {         
                $Output = $Output + "Hello Team,`n"
                $Output = $Output + "Microsoft Internet Information Services (IIS) is one of the main processess using a high percentage of the VM's CPU:`n"
                $Output = $Output + "   VM:  $($env:computername)"
                $Output = $Output + "   OS:  $($OSType)"
                $Output = $Output + "   IP:  $($LocalIpAddress)`n"
                $Output = $Output + "Process Details (Top 5) - ordered by CPU%:"
                $Output = $Output + $(ConvertTo-ASCII -data $script:ProcDetails2 -NoAddBlankLine -SortNameSwitch "ProcessName")
                $Output = $Output + "`nTypically, this can be caused by unexpected heavy load on the Web Server, or an application issue causing the Application Pool Process to exhaust available CPU cycles. If this is not expected usage and you require further assistance please contact us."
                $Output = $Output + "`n"
                $Output = $Output + "$($ticketSignature)"
                $Output = $Output + "`n***PILOT PHASE*** Please review and update wording as required before posting publicly."
            }
    #CPU LOW: Check whether CPU% counter has dropped below 75% and if so, update and set ticket to Confirm Solved status
    elseif ($ProcDetails[0].'%ProcessorTime' -lt $cpuThreshold)
            {              
                $Output = $Output + "Hello Team,`n"
                $Output = $Output + "Smart Ticket automation has detected that high CPU usage has dropped below the $($cpuThreshold)% threshold:`n"
                $Output = $Output + "   VM:  $($env:computername)"
                $Output = $Output + "   OS:  $($OSType)"
                $Output = $Output + "   IP:  $($LocalIpAddress)`n"
                $Output = $Output + "Process Details (Top 5) - ordered by CPU%:"
                $Output = $Output + $(ConvertTo-ASCII -data $script:ProcDetails2 -NoAddBlankLine -SortNameSwitch "ProcessName")
                $Output = $Output + "`nThis ticket will be set to Confirm Solved status and we will continue to monitor the VM for any further alerts; if you have any questions please let us know."
                $Output = $Output + "`n"
                $Output = $Output + "$($ticketSignature)"
            }
    #Report error if neither the if or elseif statements can run.
    else
            {
                $Output = $Output + "Error running Script via Smart Ticket Engine."
            }
    #escape any backslash so BBcode does not parse it as new lines etc
    #the double \ in the first entry is becausde its regex so we need to escape the slash as a literal character
    $Output =  $Output -Replace("\\","\\")

    $temp = $Output | Out-String
    return $temp      
}
Catch
{
    #error exception
    Return $_
}
}

Resolve-CpuAlerts | Format-List