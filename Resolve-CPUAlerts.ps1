<#
    .SYNOPSIS
    Runs analysis of CPU Usage
    
    .DESCRIPTION
    Full description: Checks for causes of high CPU usage
    WHAM - supported: Yes
    WHAM - keywords: CPU,Usage,Reslove,High
    WHAM - Prerequisites: No
    WHAM - Makes changes: No
    WHAM - Column Header: CPU Usage
    WHAM - Script time out (min): 5
    WHAM - Isolate: Yes
                
    .EXAMPLE 
    Full command: Resolve-CpuAlerts
    Output: output table
     
    .NOTES
    Last Updated: 01-FEB-2016
    Minimum OS: 2008 R2
    Minimum PoSh: 2.0

    Version Table:
    Version :: Author         :: Live Date   :: JIRA     :: QC             :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Mark Wichall   :: 08-FEB-2016 :: IAWW-000 :: Martin Howlett :: Release
    1.1     :: Martin Howlett :: 01-AUG-2016 :: IAWW-000 :: Mark Wichall   :: Fixed output bug with \r
#>
Function Resolve-CpuAlerts {
Try{

    [Array]$Global:Reason = $null

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
       Author = Mark Wichall
       Version = 0.3
       Updated = 03/03/16
       Wiki = https://one.rackspace.com/display/IAW/ConvertTo-ASCII
    #>
    #region ASCII
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


    Function Get-ProcessorHWDetails{
        Try{
            [Array]$Processor = gwmi -query "SELECT Manufacturer, Name, NumberofCores FROM win32_Processor" -ErrorAction SilentlyContinue
            
            If ($($Processor | Measure-Object).count -eq 0)
            {
                #PSO - error
                $Result = New-Object PSObject -Property @{
            	    "Processor Manufacturer" = "Error retriving CPU info";
                    "Processor Name" = "Error retriving CPU info";
                    "Cores Per Processor" = "Error retriving CPU info";
                    "Total Number of Processor/s" = "Error retriving CPU info";
                    }
                Return $Result 
            }
            Else
            {
                #PSO - CPU details returned
                $Result = New-Object PSObject -Property @{
            	    "Processor Manufacturer" = $($Processor[0].Manufacturer);
                    "Processor Name" = $($Processor[0].Name);
                    "Cores Per Processor" = $($Processor[0].NumberofCores);
                    "Total Number of Processor/s" = "$($($Processor | Measure-Object).count)";
                    }
                Return $Result 
             }
        }
        Catch
        {     
            $Result = New-Object PSObject -Property @{
            	    "Processor Manufacturer" = "Unknown error";
                    "Processor Name" = "Unknown error";
                    "Cores Per Processor" = "Unknown error";
                    "Total Number of Processor/s" = "Unknown error";
                    }
            Return $Result
        }
    }
    
    Function Get-ProcessDetails{
        Try{
            #Process list from WMI
            $Processes = Get-WmiObject Win32_PerfFormattedData_PerfProc_Process | `
            where-object{ $_.Name -ne "_Total" -and $_.Name -ne "Idle"} | `
            Sort-Object PercentProcessorTime -Descending | `
            Select-object Name,IDProcess,PercentProcessorTime -First 20;

            [Array]$Results = $null

            ForEach($Process in $Processes)
            {
                $ProcessPSO = New-Object PSObject -Property @{
                        "ProcessName" = $($Process.Name);
                        "PID" = $($Process.IDProcess);
                        "%ProcessorTime" = $($Process.PercentProcessorTime);
                        }

                        #Suspended this option as requires multiline support for output. 
                        #"Contained Processes" = $null;
                <#
                If ($($Process.Name) -like "*svchost*")
                {
                    [Array]$Filtered = $null
            
                    $Test = tasklist /svc /fi "PID eq $($Process.IDProcess)"
                    $Test | foreach {$_ -replace "svchost.exe",""} `
                    | foreach {$_ -replace "$($Process.IDProcess)",""}`
                    | foreach {$_ -replace "=",""}`
                    | foreach {$_ -replace " ",""}`
                    | foreach {$_ -replace "ImageNamePIDServices",""}`
                    | foreach {$_ -replace " ",""}`
                    | foreach {if ($_ -match "\S"){$Filtered += $_}} ;

                    $ProcessPSO."Contained Processes" = $($Filtered | Out-String);
                }
                #>
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

    Function Get-PhysicalorVirtualServer {
    Try
        {
            $Wmibios = Get-WmiObject Win32_BIOS -ErrorAction Stop | Select-Object version,serialnumber 
            $Wmisystem = Get-WmiObject Win32_ComputerSystem  -ErrorAction Stop | Select-Object model,manufacturer
            $Results = New-Object PSObject -Property @{
                "PhysicalorVirtual" = "Physical"
                "VirtualType" = $false
            }
            if ($Wmibios.SerialNumber -like "*VMware*") 
            {
                $Results."PhysicalorVirtual" = "Virtual"
                $Results."VirtualType" = "VMWare"
            }
            else 
            {
                switch -wildcard ($Wmibios.Version) 
                {
                    'VIRTUAL' {$Results."PhysicalorVirtual" = "Virtual";$Results."VirtualType" = "Hyper-V"} 
                    'A M I' {$Results."PhysicalorVirtual" = "Virtual";$Results."VirtualType" = "Virtual PC"}
                }
            }
            Return $Results
        }
        Catch
        {
        $Results = New-Object PSObject -Property @{
                "PhysicalorVirtual" = "Unknown Error"
                "VirtualType" = "Unknown Error"
            }

        Return $Results
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
                                Add-Member -InputObject $Results -MemberType NoteProperty -Name "$($Service.displayname)" -Value "$($Service.status)" -force -ErrorAction SilentlyContinue
                                $CurrentCheck = $true
                            }
                        }
                    
                        #If no matches found  
                        If (-Not $CurrentCheck)
                        {
                            Add-Member -InputObject $Results -MemberType NoteProperty -Name "$CheckService" -Value "Service name not found." -force -ErrorAction SilentlyContinue
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

    $ProcResults = Get-ProcessorHWDetails; #Processor details
    $PhysicalorVirtualServer = Get-PhysicalorVirtualServer; #VM or Physical Server
    $Connections = Get-ConnectionCount; #Connections
    
    #Boot time and up time
    #PSO - Boottime and Uptime
    $PSO = New-Object PSObject -Property @{
            "UptimeDays" = "Unknow Error";
            "Uptime" = "Unknow Error";
    	    "Boot time" = "Unknow Error";
            } 
           
    #Boottime
    $PSO."Boot Time" = Get-BootTime;

    #UpTime
    $Uptime = Get-Uptime
    $PSO."UptimeDays" = $($Uptime."UptimeDays");
    $PSO."Uptime" = $($Uptime."UptimeDays");

    #Process Details
    [Array]$ProcDetails = Get-ProcessDetails;

    [Array]$CheckServices = "SQL","World Wide Web Publishing Service","Cluster Service";
    [Array]$Services = Get-CoreServices -CheckServices $CheckServices;

    #########################
    # Resons/Recomendations #
    #########################

    #Flag if more than 8 cores allocated to a VM
    If (($($PhysicalorVirtualServer."PhysicalorVirtual") -eq "Virtual") -and ($($PhysicalorVirtualServer."VirtualType") -eq "vmware") -and ($($ProcDetails."Cores Per Processor") -gt 8))
    {
        $RecTemp = New-Object PSObject -Property @{             
        "Reason" =  "VM has more than 8 cores assinged. This can cause perfomrance issues on vmware";  
        }
        $Global:Reason += $RecTemp
    }

    ################
    # Build Output #
    ################

    [Array]$Output = $null

    $Output = $Output + " " #add blank line
    $Output = $Output + "Server:  $env:computername"

    $Output = $Output + " " #add blank line
    $Output = $Output + "Possible Reasons for High CPU"
    If (($($Global:Reason) | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $Global:Reason)
    }
    Else
    {
       $Output = $Output + "-----------------------------------------------------------------"
       $Output = $Output + "*** No Reasons Found check full report below. ***"
       $Output = $Output + "Note: Phase 2 of deployment will include this logic"
    }
    
    $Output = $Output + $Global:Reason
    
    $Output = $Output + " " #add blank line
    $Output = $Output + "Below is the full report from the script for server $env:computername"
    $Output = $Output + "-----------------------------------------------------------------"
    $Output = $Output + " " #add blank line

    #Processor details
    $Output = $Output + " "
    $Output = $Output + "Processor Hardware Details: "
    If (($ProcResults | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $ProcResults -List -NoAddBlankLine)
    }
    Else
    {
       $Output = $Output + "Error retreiving results."
    }
    $Output = $Output + " " #add blank line
  
    #VM or Physical Server
    $Output = $Output + " "
    $Output = $Output + "Is Server Physical or Virtual: "
    If (($PhysicalorVirtualServer | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $PhysicalorVirtualServer -List -NoAddBlankLine)
    }
    Else
    {
       $Output = $Output + "Error retreiving results."
    }
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
    $Output = $Output + "Server Connections: "
    If (($Connections | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $Connections -List -NoAddBlankLine -SortNameSwitch "Established")
    }
    Else
    {
       $Output = $Output + "Error retreiving results."
    }
    $Output = $Output + " " #add blank line      

    #Process Details
    $Output = $Output + " "
    $Output = $Output + "Process Details: "
    If (($ProcDetails | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $ProcDetails -NoAddBlankLine -SortNameSwitch "ProcessName")
    }
    Else
    {
       $Output = $Output + "Error retreiving results."
    }
    $Output = $Output + " " #add blank line

    #Are Core services installed and running
    $Output = $Output + " "
    $Output = $Output + "Services Check: "
    If (($Services | Measure-Object).Count -gt 0)
    {
        $Output = $Output + $(ConvertTo-ASCII -data $Services -List -NoAddBlankLine)
    }
    Else
    {
       $Output = $Output + "Error retreiving results."
    }
    $Output = $Output + " " #add blank line

    #escape any backslash so BBcode does not parse it as new lines etc
    #the double \ in the first entry is becausde its regex so we need to escape the slash as a literal character
    $Output =  $Output -Replace("\\","\\")

    $temp = New-Object PSObject -Property @{
        Server = $ENV:ComputerName
        Report = ($Output | Out-String)
    }
    return $temp          
}
Catch
{
    #error exception
    Return $_
}

}
#start-wham -download -norun ; .\Wham_controller.ps1 -nologging -templateqc -templatename "Resolve-CpuAlerts" -account 1103359 -DisableConfirmation -OutputOptions 2