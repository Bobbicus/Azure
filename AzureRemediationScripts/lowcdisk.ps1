<#
    .SYNOPSIS
    Runs analysis for disk space alerts
    
    .DESCRIPTION
    Full description: Checks for the most common causes of disk space problems and advises on actions
    - supported: Yes
    - keywords: Alert,smart tickets,disk space
    - Prerequisites: No
    - Makes changes: Yes
    - Changes Made: 
        Empties recycle bin
        Enables ntfs compression on certain folders
    - Column Header: Disk space alert
    - Script time out (min): 15
    - Isolate: Yes
            
     
    .EXAMPLE 
    Full command: Resolve-DiskSpaceAlert -Remediate Y -Force | Select-object Report | Format-List

    .NOTES
    Lots of input from various wikis, Mark Wichall and Steve Conisbee original script
    Last Updated: 06-OCT-2015
    Minimum OS: 2008 R2
    Minimum PoSh: 2.0

    Version Table:
    Version :: Author         :: Live Date   :: JIRA      :: QC             :: Description
    -----------------------------------------------------------------------------------------------------------
#>

Function Resolve-DiskSpaceAlert
{
  Param(
    [Parameter(Mandatory=$false)]$DriveLetter = "C:",
    [Parameter(Mandatory=$false)]$Remediate,
    [switch]$Force
    )

try{
    
    #Add the colon if the user doesnt
    if($DriveLetter -notlike "*:"){
        $DriveLetter = "$DriveLetter`:"
    }

    #Skip the user validation if the force parameter is used
    if (-not $force) 
    {        
        #confirm run remediation locally
        if((Read-Host "REMEDIATE the alert(Y/N)? Makes Changes,proceed with Caution, proceed with Caution.") -like "y*")
        {
            $Remediate = "Y"
        }
    }

    #Define folder limit in GB to add recommendations
    $Limit = 0.99

    $Global:Recommendations = @()

    #Remediation Log file Location
    $LogFile = 'D:\DiskCleanupResults.txt'

    #Threshold to autoclose ticket
    #measured in bytes:
    #1GB = 1073741824
    #90Gb = 96636764160
    $FreespaceThreshold = '1073741824'
    

    #################### Helper Functions - BEGIN ####################
    #region 

    Function ConvertTo-ASCII{
    <#
    .Synopsis
       Converts a PSO or array of PSO's in an a ASCII table.

    .DESCRIPTION
       Outputs the content of the PSO or array of PSO's in an a ASCII table.
       Only converts data when PSO contains NoteProperties, otherwise it retruns origonal data.
       This means that you can send your data through this function and it will convert it if 
       it's a PSO/Array or PSO's and it will just pass through an other data.

       Example of data being pass through function would just return "A String"
       Get-ASCIITable -Data "A String" -AddLines -List

       If a PSO or and array of PSO's is passed in there converted to a table.  See examples.
       Get-ASCIITable -Data $PSO -AddLines -List

    .PARAMETER Data
        Optional
        Switch
        Expected input is either an Array or PSO's or PSO which will be converted to a table
        or any other data type which will not be converted but instead retruned.

    .PARAMETER AddLines
        Optional
        Switch
        Adds lines between pso's in table

    .PARAMETER Clip
        Optional
        Switch
        Outputs to clipboard

    .PARAMETER NoReturn
        Optional
        Switch
        if true doesn't return output

    .PARAMETER List
        Optional
        Switch
        Formats output in a list

    .PARAMETER NoAddBlankLine
        Optional
        Switch
        Doesn't automatically add a blank line before table to fix formating with clip or copy and paste

    .PARAMETER SortDescending
        Optional
        Switch
        Sorts Collmuns in Descending order

    .PARAMETER SortNameSwitch
        Optional
        String
        Sorts the string value Collmun to be first in the table

    .PARAMETER EscapeSlash
        Optional
        Switch
        Replaces \ with \\ this is used to escape line break charatures in file paths    

    .EXAMPLE
       If an opject other than a PSO or Array of PSO's is passed to the function it retruns the origonal object
       Get-ASCIITable -Data "A String"

       Retuns:
       A String

    .EXAMPLE
       A PSO of data
       ConvertTo-ASCII -Data $Data

        +---------------------+------+--------+-------------------------+
        | Date                | Name   | Server       | Status          |
        |===============================================================|
        | 03/07/2017 08:42:14 | server | 11111-server | Online/complete |
         +---------------------+------+--------+------------------------+

    .EXAMPLE
        Array of PSO's retruned 
        ConvertTo-ASCII -Data $Data

         +---------------------+---------+--------------------+-----------------+
         | Date                | Name    | Server             | Status          |
         |======================================================================|
         | 03/07/2017 08:42:14 | Server1 | 1111-Server1       | Other           |
         | 03/07/2017 08:42:14 | Server2 | 2222-Server2       | Online/Complete |
         | 03/07/2017 08:42:14 | Server3 | 3333-Server3       | Colo            |
         +---------------------+---------+--------------------+-----------------+

    .EXAMPLE
        Array of PSO's retruned as a list table
        ConvertTo-ASCII -Data $Data -List

         +--------+---------------------+
         | Date   = 03/07/2017 08:42:14 |
         | Name   = server              |
         | Server = 11111-server        |
         | Status = Online/complete     |
         +--------+---------------------+
   
    .OUTPUTS
        If the input is an Array or PSO's or PSO the code will retrun the data converted to a table
        If the input is any other data type which will not be converted but instead retruned.   

    .NOTES


       Version Table:
        Version :: Author         :: Live Date   :: JIRA       :: QC             :: Description
        -----------------------------------------------------------------------------------------------------------
        1.3     :: Mark Wichall   :: 19-MAY-2017 :: IAWW-1269  :: Martin Howlett :: removed out-string of ascii table as it was adding a following line
    #>

        Param
        (
            [Parameter()]
            [AllowEmptyCollection()]
            [Array]$Data,

            [Parameter()]
            [Switch]$AddLines,

            [Parameter()]
            [Switch]$Clip,
       
            [Parameter()]
            [Switch]$NoReturn,

            [Parameter()]
            [Switch]$List,

            [Parameter()]
            [Switch]$NoAddBlankLine,

            [Parameter()]
            [Switch]$SortDescending,

            [Parameter()]
            [String]$SortNameSwitch,

            [Parameter()]
            [Switch]$EscapeSlash
        )

        Begin
        {
            Write-Verbose "Start of $($MyInvocation.MyCommand)"
        }

        Process
        {
            Try
            {           
                #Initialize PSO
                $ContentSizePSO = New-Object PSObject

                #Gets Collmun names in Data PSO, for noteproperty's
                $ColNames = $Data | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name
            
                #Predefining types as string so .length counts the string length
                [String]$NameString = $null

                If (($ColNames | Measure-Object).count -eq 0)
                {
                    Write-Verbose "Note: Data param was either empty or didn't contain a PSO with NoteProperties, retruning origonal data."
                    #escapes \ charature by replacing them with \\
                    If ($EscapeSlash)
                    {
                            $NameString = $Data | Out-String
                            $Data = $NameString.replace("\","\\")     
                    }
                    Return $data
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

                Write-Verbose "After `$ColNames Sort"

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
                            #makes sure colname is a string
                            $NameString = $ColName

                            #escapes \ charature by replacing them with \\
                            If ($EscapeSlash)
                            {
                                 $NameString = $NameString.replace("\","\\")  
                                 $ColName = $NameString     
                            }

                            #length of collumn name
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
                                #makes sure data is a string
                                $CollString = $DataPSO.$ColName

                                #escapes \ charature by replacing them with \\
                                If ($EscapeSlash)
                                {
                                     $CollString = $CollString.replace("\","\\")  
                                     $DataPSO."$ColName" = $CollString     
                                }
                            
                                #Checks the length of the data
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
                        Write-Verbose "Error: Could not inventory PSO or Array of PSO's"
                        Return $data
                        Break
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
                            #makes sure colname is a string
                            $NameString = $ColName
                        
                            #escapes \ charature by replacing them with \\
                            If ($EscapeSlash)
                            {
                                 $NameString = $NameString.replace("\","\\")  
                                 $ColName = $NameString     
                            }

                            #length of collumn name
                            $maxline = $NameString.length
               
                            #max length of content of collumn        
                            Foreach ($item in $Data)
                            {
                                #makes sure content is a string
                                $ContentString = $($item.$NameString)

                                #makes sure colname is a string
                                $NameString = $ColName
                        
                                #escapes \ charature by replacing them with \\
                                If ($EscapeSlash)
                                {
                                     $ContentString = $ContentString.replace("\","\\")  
                                     $item."$NameString" = $ContentString     
                                }

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
                        Write-Verbose "Error: Could not inventory PSO or Array of PSO's"
                        Return $data
                        Break
                    }

                    #Gets Collum names in Content Size PSO e.g. size of the data in the Data PSO
                    #$ContentSizeNames = $ContentSizePSO | get-member -membertype NoteProperty -ErrorAction SilentlyContinue | select name
        
                    If (($ColNames | Measure-Object).count -eq 0)
                    {
                        Write-Verbose "Error: Error retriving collmun names in Content Size PSO."
                        #escapes \ charature by replacing them with \\
                        If ($EscapeSlash)
                        {
                                $NameString = $Data | Out-String
                                $Data = $NameString.replace("\","\\")     
                        }
                        Return $data
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
                    Write-Verbose "Output sent to clipboard"
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
                    Write-Verbose "Error Converting PSO/Array of PSO's to ASCII table"
                    Return $data
            }
        }
        End
        {
            Write-Verbose "End of $($MyInvocation.MyCommand)"
        }
    }

    Function Start-JobTimeout{
    <#
        .SYNOPSIS
        Manages creation of a powershell job with built in timeout value
    
        .DESCRIPTION
        Starts a powershell job with scriptblock provided, adds a timeout for that job
        It is advised that 
         -  any code run in this way is as simple as possible ideally a one liner
         - any code limits the results retruned so that your not storing a very large object in memory 
           for example if using get-childitem -resurse, filter result returned e.g. select -last 10
        Returns a PSO object containg any errors and the result
        When job is started it's started using a name, code check if that named job already exists and won't run a duplicate.  
        This is session based so only one user can run the code at a time.
          
        .PARAMETER StringScriptblock
        Mandatory
        String
        Code in string form to run in the job

        .PARAMETER JobName
        Mandatory
        String
        Name of Job to use and check if it already exists

        .PARAMETER TestJob
        Switch
        Test if a simple job can be created and run

        .PARAMETER TimeOut
        Int
        Time out in seconds for the powershell job
        Default value is 300 seconds e.g. 5 minutes.

        .EXAMPLE
        basic example retruns "Test"
        Start-JobTimeout -StringScriptblock "retrun 'Test'" -JobName "NewTestJob1" -TestJob
    
        .EXAMPLE
        examples causes a timeout to demonstrate the job will be stopped and removed
        Start-JobTimeout -StringScriptblock "start-sleep 50; retrun 'Test'" -JobName "NewTestJob1" -TestJob -Timeout 30

        .EXAMPLE
        Run's get-childitem which can run for long periods of time and use up resource on servers large disk/files/dirs
        Start-JobTimeout -StringScriptblock "get-childitem c:\ -recursive -depth 2" -JobName "NewTestJob1" -TestJob -Timeout 300

        .EXAMPLE
        Run's get-childitem where the $var is equal to the drive letter
        $var = "c:";Start-JobTimeout -StringScriptblock "get-childitem $var" -JobName "NewTestJob1" -TestJob -Timeout 300

        .EXAMPLE
        Run's get-childitem where the $var is equal to the drive letter
        Any double quotes in the string need to be replaced by single quotes to not escape the string
        Any variables you don't want to replace with there value in the string but processed as a var have to be escaped e.g. `$_.Length

        $var = "c:"; Start-JobTimeout -StringScriptblock "get-childitem $var | select-object name,@{Name='Size (MB)';Expression={[Math]::Truncate(`$_.Length / 1MB)}}" -JobName "NewTestJob1" -TestJob -Timeout 300

        .OUTPUT
        a PSO object containing the result, any errors and the code run

        JobOutput = output of job
        JobStatus = job status
        JobError = any error
        JobTimeout = timeout set
        JobScript = The code that was run
        JobLoopTime = An idea of how long the job looped for before it completed, help with testing and determining the timeout to give.

        .NOTES
        Written by Mark Wichall
    #>

        [CmdletBinding()]

        Param
        (
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()] 
            [String]$StringScriptblock,

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()] 
            [String]$JobName,

            [Parameter()]
            [ValidatePattern("^[1-9]{1}[0-9]{0,2}$")]
            [Int]$TimeOut = 300,
            #timeout for job 300 seconds = 5 minutes, max time out allowed is 999 seconds

            [Parameter()]
            [Switch]$TestJob
        )

        Write-Verbose "Start of $($MyInvocation.MyCommand)"
   
        #################### Test Jobs - BEGIN ####################
        #region 

        #Convert string to scriptblock
        $scriptBlock = [Scriptblock]::Create($StringScriptblock) 

        # Run a test PS Job and make sure device can run jobs. Any exception means, most likely, PSRemoting is disabled or similar.
        [Switch]$UseJobs = $true

        #Output Job PSO
        $Result = New-Object PSObject -Property @{
                JobOutput = "";
                JobStatus = "";
                JobError = $false;
                JobTimeout = "$timeout";
                JobScript = "$scriptBlock"
                JobLoopTime = ""
                }

        #Test if jobs work on this server, use switch param TestJob
        If ($TestJob)
        {
            Try 
            {
	            Write-Verbose "Starting - Powershell Job Test"

                $TestString = "Can I Job it?"
		        ($TestingJob = Start-Job {Write-Output $args} -ArgumentList $TestString)| Out-Null
		        Wait-Job $TestingJob | Out-Null
		        $TestJobResult = Receive-Job $TestingJob
		        Remove-Job $TestingJob | Out-Null
		        If ($TestJobResult -ne $TestString)	
                {
                    #job failed to retrun expected result
                    Throw "Failed to create a powershell job"
		        }
                Write-Verbose "Completed - Powershell Job Test"
	        }
	        Catch 
            {
                #Failed to create job
                Write-Verbose "Failed - Powershell Job Test"
                $UseJobs = $False

                #Output Job PSO
                $Result.JobError = $true
                $Result.JobOutput = "Powershell failed to start a simple test Job, psremoting may not be enabled"
                Return $Result
	        }
        }

        #endregion 
        ##################### Test Jobs - END #####################

        #################### Check if Job Already Exists - BEGIN ####################
        #region

        #Successfully ran job before to will try to use jobs for get-childitem
        If ($UseJobs)
        {
            #Check if already job exists and quit if it does exist.
            #if the name doesn't exist it would error which is why silentlycontinue is set.
            $JobState = Get-Job -Name "$JobName" -ErrorAction SilentlyContinue
            If ($JobState)
            {
                #Quits and returns error
                Write-Verbose  "Failed - Powershell Job ($JobName) already exists"

                #Output Job PSO
                $Result.JobError = $true
                $Result.JobStatus = "Duplicate Job"
                $Result.JobOutput = "Powershell Job ($JobName) is already present, preventing creation of duplicate job"
                Return $Result
                #running, File search is disabled in this run of the template
            }
        }

        #endregion 
        ##################### Check if Job Already Exists - END #####################

        #################### Start and Loop Job - BEGIN ####################
        #region 

        Write-Verbose "Starting - Powershell Job ($JobName)"
        Write-Verbose "Powershell Job ($JobName) Script block:"
        Write-Verbose "$Scriptblock"

        #Try starting the job
        Try
        {
            ($StartJob = Start-Job -Name "$JobName" -ScriptBlock $Scriptblock -ErrorAction Stop) | Out-Null
            Write-Verbose "Created - Powershell Job ($JobName)"
        }
        Catch
        {
            #Quits and returns error
            #Output Job PSO
            $Result.JobError = $true
            $Result.JobOutput = "Powershell Job ($JobName) failed to created"
            Return $Result
        }

        #Vars for job check loop
        [Switch]$jobresult = $false #check if job has returened a result
        [Int]$sleepseconds = 5 #Sleep between checks
        [Int]$runtime = 0 #counts the run time

        #If job was created check the status of the job
        Do
        {
            #Gets the status of the job
            $JobState = Get-Job -Name "$JobName" -ErrorAction SilentlyContinue

            Write-Verbose "Powershell Job ($JobName) - Job State ($($JobState.State) | Run Time ($runtime)"

            #Checks the status of the job
            If ($JobState.State -eq "Running")
            {
                #job not complete so start sleep for x seconds.
                start-sleep $sleepseconds
                $runtime += $sleepseconds
            }
            Else
            {
                #job complete
                $jobresult = $true
            }
        }
        Until (($runtime -gt $timeout) -or ($jobresult -eq $true))
        #Quits if running time of the loop is more than the timeout value
        #Quits if job completed
    
        #Powershell Job status and runtime
        $result.JobStatus = $($JobState.State)
        $result.JobLoopTime = $runtime


        #Check if result returned or timed out.
        If ($runtime -gt $timeout)
        {
            #Output Job PSO
            $Result.JobError = $true
            $Result.JobOutput = "Expected Exception:PowerShell job over ran timed out ($timeout seconds) and was stopped to prevent performance impact "
        }
        ElseIf ($JobState.State -eq "Completed")
        {
            Try
            {
                $JobContent = Receive-Job -Name "$JobName" -ErrorAction Stop
                $Result.JobOutput = $JobContent | select -Property * -ExcludeProperty PSComputerName,PSShowComputerName,RunspaceId
                Write-Verbose "Receive Job - Powershell Job ($JobName)"
            }
            Catch
            {
                #Output Job PSO
                $Result.JobError = $true
                $Result.JobOutput = "Error Job Failed to return a result "
            }
        }
        Else
        {
            #Output Job PSO
            $Result.JobError = $true
            $Result.JobOutput = "Error Job ($JobName) Status ($($JobState.State)) "
        }

        #Clean up jobs
        Stop-Job -Name $JobName -ErrorAction SilentlyContinue | Out-Null
        Remove-Job -Name $JobName -Force -ErrorAction SilentlyContinue | Out-Null
           
        #endregion 
        ##################### Start and Loop Job - END #####################

        Write-Verbose "End of $($MyInvocation.MyCommand)"

        return $Result
    }


    #endregion 
    ##################### Helper Functions - END #####################
    Function Log-Changes{
    <#
        .SYNOPSIS
        Creates a log file if it dones't exist and add text to it.
        
        .DESCRIPTION
        Creates a log file if it dones't exist and add text to it.
          
        .PARAMETER Data
        String
        String to add to log file

        .PARAMETER Date
        Switch
        switch to add date to log file

        .PARAMETER LogFile
        String
        Path to log file

        .EXAMPLE
        Adds an entry to a log file
        Log-Changes -Date -Data "Write help for function -LogFile C:\temp\todolist.txt" -Date

        .OUTPUT
        String add to text file

        .NOTES
        Written by John Luikart
    #>

        Param(
            [Parameter(Mandatory=$true)][string[]]$Data,
            [Parameter(Mandatory=$true)][string]$LogFile,
            [Parameter()][switch]$Date
        )
        try{
            If ($Date){
                $Time = "$(Get-Date -Format G): "
                $Lines = $data | Foreach-Object { "$Time$_" }
            }
            else{
                $Lines = $data | Foreach-Object { "   $_" }
            }

            add-content -path $LogFile -value $lines
        }
        catch{
            "Error writing data: $Data to log file  "
            "Error message: $($_.Exception.Message)"
            return
        }
    }
    #################### Audit Functions - BEGIN ####################
    #region 

    Function Get-FolderSize{
    Param(
        [Parameter(Mandatory=$true)]$FolderPath
        )

        if (Test-Path $FolderPath -ErrorAction SilentlyContinue){
            try{
            $Size = (Get-ChildItem $FolderPath -recurse -Force -ErrorAction SilentlyContinue | Measure-Object -property length -sum -ErrorAction SilentlyContinue).Sum
            }
            catch
            {
                #Do nothing
                #This is a work around when using -force we get some errors that override "SilentlyContinue"  but -force is necessary to get hidden files including contents of recycle bin
            }
            return $([Math]::Round($($Size / 1GB), 2))
        }else{
            return $false
        }
    }

    Function Get-FolderCompressed {
        Param(
            [Parameter(Mandatory=$true)]$Folder
        )
        $FolderCompressed = Get-Item "$Folder" -ErrorAction SilentlyContinue | Where-Object {$_.attributes -match "compressed"}
        if($FolderCompressed){
            return $true
        }else{
            return $false
        }
    }

    Function Add-Recommendations {
        Param(
            [ValidateSet("Caution","Action","Customer")]
            [Parameter(Mandatory=$true)]$Category,
            [Parameter(Mandatory=$true)]$Recommendation,
            [Parameter(Mandatory=$true)]$SpaceUsed
        )

        #We add a sort order as we need to sort descending to give us largest space first
        switch ($Category){
            "Caution" {
                $CategoryDesc = "Action with caution"
                $SortOrder = 2
            }
            "Action" {
                $CategoryDesc = "Action immediately"
                $SortOrder = 3    
            }
            "Customer" {
                $CategoryDesc = "Recommend to customer before action"
                $SortOrder = 1   
            }
        }

        $RecTemp = New-Object PSObject -Property @{             
            "Category" =  $Category
            "CategoryDesc" = $CategoryDesc
            "Recommendation" = $Recommendation
            "Space Used GB" = $SpaceUsed
            "SortOrder" = $SortOrder
        }
        $Global:Recommendations += $RecTemp
    }

    Function Get-PageFileSettings{  
        #Query WMI
        $PageFile = Get-WmiObject Win32_PageFileusage -erroraction SilentlyContinue | Select-Object Name,AllocatedBaseSize,PeakUsage | Where-Object {$_.Name -like "$DriveLetter\*"}

        #if WMI doe not return anything, error out
        If (-NOT $PageFile)
        {
            $Output = New-Object PSObject -Property @{
                "Pagefile Location" = "Pagefile not on $DriveLetter"
                "Pagefile Size" = "Pagefile not on $DriveLetter"
                "Pagefile Peak Usage" = "Pagefile not on $DriveLetter"
            }
            Return $Output
            break
        }
        else
        {
            $Output = New-Object PSObject -Property @{
                "Pagefile Location" = $PageFile.Name
                "Pagefile Size (GB)" = [Math]::Round(($PageFile.AllocatedBaseSize / 1024),2)
                #round to 2 decimals
                "Pagefile Peak Usage (GB)" =  [Math]::Round(($PageFile.PeakUsage / 1024),2) 
            }
    
            Return $Output
        }
    }
  
    #endregion 
    ##################### Audit Functions - END #####################

    #################### Remediation Functions - BEGIN ####################
    #region 

    Function Clear-RecycleBin{
    <#
    .SYNOPSIS
    Clears the recycle bin
        
    .DESCRIPTION
    Clears the recycle bin
          
    .PARAMETER DriveLetter
    String
    String to add to log file

    .EXAMPLE
    Clears the recycle bin on c: drive.
    Clear-RecycleBin -DriveLetter c:

    .OUTPUT
    PSO object of result

    .NOTES
    Written by John Luikart
    #>

        Param(
            [Parameter(Mandatory=$true)]$DriveLetter
        )
        try{
            #WM5 includes "Clear-RecycleBin Until then, we have to use this

            $Output = New-Object PSObject -Property @{
                "Items Removed" = ''
                "Megabytes Removed" = ''
                "List of Files" = ''
                "ErrorMsg" = $null
            }
            $Shell = New-Object -ComObject Shell.Application 
            $ListOfFiles = New-Object System.Collections.Generic.List[System.Object]
            $RecBin = $Shell.Namespace(0xA) 
            $RecBin.Items() | Where-Object {$_.Path -like "$driveletter*"} | ForEach-Object{
                Remove-Item $_.Path -Recurse -Confirm:$false
                ++$NumberRecycleBinItemsDeleted
                $SizeOfDeletedRecycleBinItems = $SizeOfDeletedRecycleBinItems + $_.Size
                $ListOfFiles += $_.Name
            }
            $Output.'Items Removed' = $NumberRecycleBinItemsDeleted
            $Output.'Megabytes Removed' = "{0:N0}" -f ($SizeOfDeletedRecycleBinItems/1048576)
            $Output.'List of Files' = $ListOfFiles

            Log-Changes "Emptied the following files from recycle bin:" -Date -LogFile $Logfile
            Log-Changes $($output.'List of Files') -LogFile $Logfile
            return $Output
        }
        catch{
            $Output.ErrorMsg = "ERROR: Recycle Bin is already empty."
            Return $Output
        }
    }
    Function Enable-NTFSCompression{
        param(
            $FoldersThatCanBeCompressed
        )
        $Output = New-Object PSObject -Property @{
            "Space Recovered (MB)" = ''
            "Successfully Compressed" = ''
            "ErrorMsg" = $null
        }
        try{
        if (-not $FoldersThatCanBeCompressed){Break}
        $After = $null
        $Result = $null
        $Failed = New-Object System.Collections.Generic.List[System.Object]
        $Success = New-Object System.Collections.Generic.List[System.Object]
        $SpaceFreedByCompression = $null
        #Can't measure the size of the folder, because it doesn't use "Size on disk"  As a work around to see how much we helped, we measure the whole disk free space
        [int]$Before = ((Get-WmiObject -Class Win32_LogicalDisk) | Where-Object {$_.DeviceID -EQ $DriveLetter} | select -ExpandProperty FreeSpace) / 1048576
        foreach ($FolderThatCanBeCompressed in $FoldersThatCanBeCompressed)
        {
            if (Test-Path $FolderThatCanBeCompressed -ErrorAction Ignore){  #if shouldn't be needed since I'll be using the part that Mark wrote to make it go
                #Compress the folder and record whether there was an error or not
                $Result = Invoke-WmiMethod -Path "Win32_Directory.Name='$FolderThatCanBeCompressed'" -Name compress
                if (($Result.returnvalue) -eq 0) { $Success.Add($FolderThatCanBeCompressed) } else { $Failed.Add($FolderThatCanBeCompressed) }
                $SpaceFreedByCompression = $SpaceFreedByCompression + ($Before - $after)
            }
        }
        [int]$After = ((Get-WmiObject -Class Win32_LogicalDisk) | Where-Object {$_.DeviceID -EQ $DriveLetter} | select -ExpandProperty FreeSpace) / 1048576

        $Output.'Space Recovered (MB)' = $After - $Before
        $Output.'Successfully Compressed' = $Success

        Log-Changes "Compressed the following folders:" -Date -LogFile $Logfile
        Log-Changes $($Output."successfully compressed") -LogFile $Logfile
        return $Output
        }
        catch{
            $Output.ErrorMsg  += "Error message: $($_.Exception.Message)"
            return $Output
        }
    }

    #endregion 
    ##################### Remediation Functions - END #####################

    #################### Output psobject - BEGIN ####################
    #region 

    $Output = New-Object PSObject -Property @{
        "Disk" = ""
        "Top 10 files" = ""
        "Large profiles" = ""
        "Pagefile" = ""
        "Folders" = ""
        "IISLogSummary" = ""
        "SQLSummary" = ""
        "Recommendations" = @()
        "Remediation" = @()
    }

    #endregion 
    ##################### Output psobject - END #####################
    $Global:Recommendations = @()

    #################### Validate disk path - BEGIN ####################
    #region 

        if(-NOT (Test-Path $DriveLetter -ErrorAction SilentlyContinue)){
            $Output.Disk = "Disk $DriveLetter not found"
            $Output."Top 10 files" = "Disk $DriveLetter not found"
            $Output."Large profiles" = "Disk $DriveLetter not found"
            $Output."Pagefile" = "Disk $DriveLetter not found"
            $Output."Folders" = "Disk $DriveLetter not found"
            $Output."IISLogSummary" = "Disk $DriveLetter not found"
            $Output."SQLSummary" ="Disk $DriveLetter not found"
            $Output."Recommendations" = "Disk $DriveLetter not found"
            return $Output
            break
    }

    #endregion 
    #################### Validate disk path - END #####################

    #################### Disk size/files - BEGIN ####################
    #region 
    
    #Checks for the approx number of files on disk.
    Try
    {
        $NumberofFiles = $null
        $fsutil = fsutil fsinfo ntfsinfo $DriveLetter
        #Find line Mft Valid Data Length in the output of fsutil
        $MftValidDataLength = $fsutil | where-object {$_ -like "*Mft Valid Data Length*"}
        #split on the : and then remove white space to get the value
        $Value = $MftValidDataLength.Split(":")[-1] -replace '\s+',''
        $NumberofFiles  = $Value / 1024 

        If (-Not ($NumberofFiles -match '^\d+$'))
        {
            $NumberofFiles = "Unknown Error"
        }
    }
    Catch
    {
        $NumberofFiles = "Unknown Error" 
    }

    $Volumes = (Get-WmiObject -Class Win32_LogicalDisk) | Select-Object Name, VolumeName, FreeSpace, DriveType, Size
    $Disk = $Volumes | where-object {$_.Name -like $DriveLetter}
    $Diskoutput = New-Object PSObject -Property @{
                    "DiskSize (GB)" = $([math]::Round($Disk.Size/1GB,2))
                    "FreeSpace (GB)" = $([math]::Round($Disk.FreeSpace/1GB,2))
                    "PercentFree"=”{0:N2}” -f $(($Disk.FreeSpace/$Disk.Size)*100)+”%” 
                    "Number of Files (Approx)" = $NumberofFiles
    }
    $Output."Disk" = (ConvertTo-ASCII $Diskoutput -NoAddBlankLine)

    #endregion 
    ##################### Disk size/files - END #####################
    
    #################### Large profiles - BEGIN ####################
    #region 

    #Check if path exists before running get-childitem
    If (Test-Path "$DriveLetter\Users")
    {
        $GetChildItemJob2 = Start-JobTimeout -StringScriptblock "Get-ChildItem '$DriveLetter\Users' -ErrorAction SilentlyContinue -Force" -JobName "JobChildItemUsers" -Timeout 120

        #Check if there was an error
        If ($GetChildItemJob2.JobError -eq $false)
        {
            #User profiles
            $profilefolders = $GetChildItemJob2.JobOutput

            If($profilefolders)
            {
                $Profiles = @()
                foreach ($folder in $profilefolders)
                {
                    
                    #IF (($folder.name -match "^[a-z]{2,4}\d{4,5}$") -or ($folder.name -match "^[a-z]{3,}.[a-z]{3,}$") -or ($folder.name -match "[a-z]{3,}.cust$"))
                    #originally i was going to regex it, then i realise it make more sense to show profiles bigger then 0.25GB, as a customer might have a massive one
                    $ProfileSize = $null
                    $ProfileSize = Get-FolderSize -FolderPath $folder.fullname
                    if($ProfileSize -gt $Limit)
                    {
                        $ProfileTemp = New-Object PSObject -Property @{
                            "Profile name" = $folder.name
                            "Size GB" = $ProfileSize 
                        }
                        $Profiles += $ProfileTemp
                        $TotalProfileSize =  $TotalProfileSize + $ProfileSize 
                        Add-Recommendations -Category "Action" -Recommendation  "Profile $($folder.name) is over $limit`GB" -SpaceUsed $ProfileSize 
                    }
                }

                #sort profiles by size
                if($Profiles)
                {
                    $data = $($Profiles | Sort-Object "Size GB" -Descending)
                    $output."Large profiles" =  ConvertTo-ASCII -Data $Data -NoAddBlankLine
                }
                else
                {
                    $output."Large profiles" = "No profiles over $limit GB "
                }
            }
            else
            {
                $output."Large profiles" = "Error Nothing returned: $($GetChildItemJob2.JobOutput) "
            }
        }
        else
        {
            $output."Large profiles" = "Unable to run Large profiles checks "
            $output."Large profiles" += "$($GetChildItemJob2.JobOutput)"
        }
    }
    else
    {
        $output."Large profiles" = "No users folder found on drive $DriveLetter"
    }

    #endregion 
    ##################### Large profiles - END #####################

    ######################
    #page file location
    ######################
    $Pagefile = Get-PageFileSettings
    if($Pagefile."Pagefile Location" -like "$DriveLetter\*"){
            $PagefileData = New-Object PSObject -Property @{
                "Location" = $Pagefile."Pagefile Location"
                "Size (GB)" = $Pagefile."Pagefile Size (GB)"
            }
            Add-Recommendations -Category "Customer" -Recommendation "Consider moving page file to a different drive (as a last resort)" -SpaceUsed $($Pagefile."Pagefile Size (GB)")
            $output."Pagefile" = ConvertTo-ASCII $PagefileData -NoAddBlankLine
    }else{
        $output."Pagefile" = "Pagefile not present on $DriveLetter"
    }


    ######################
    #Common folder locations
    ######################

    $FolderList = @(
    #    "$DriveLetter\Windows\Installer"
        "$DriveLetter\Windows\inf"
    #    "$DriveLetter\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp"
    #    "$DriveLetter\RECYCLER"
        "$DriveLetter\`$Recycle.Bin"
    #    "$DriveLetter\Windows\Microsoft.NET\Framework64\v1.1.4322\Temporary ASP.NET Files"
    #    "$DriveLetter\Windows\Microsoft.NET\Framework64\v2.0.50727\Temporary ASP.NET Files"
    #    "$DriveLetter\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files"
    #    "$DriveLetter\Windows\winsxs"
    #    "$DriveLetter\Windows\SoftwareDistribution"
    )

    $CompressableFolders = @(
        "$DriveLetter\Windows\Installer"
        "$DriveLetter\Windows\inf"
    #    "$DriveLetter\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp"
    )

    $Folders = @()
    $FoldersToCompress = New-Object System.Collections.Generic.List[System.Object]
    ForEach ($Folder in $FolderList){
        $foldersize = $null
        if(Test-Path $Folder -ErrorAction SilentlyContinue){
                Write-Verbose "folder $Folder"
                $foldersize = Get-FolderSize -FolderPath $Folder
                $Foldersize = "$foldersize"
                $FolderCompressed = $null
                $FolderCompressed = Get-FolderCompressed -Folder $Folder

                #if its over 500MB, recommend deleting something (i know the elseif is lazy...)
                if ($foldersize -gt 0.5){
                    switch -wildcard ($folder)
                    {
                        "*Temporary ASP.NET Files*" {
                            Add-Recommendations -Category "Customer" -Recommendation "Temporary ASP.NET Files is larger then 500MB, consider deleting this folder  $Folder" -SpaceUsed $foldersize
                        }
                        "*winsxs" {
                            #check 5gB
                            if($foldersize -gt 5){
                                Add-Recommendations -Category "Caution" -Recommendation "$Folder is larger then 5GB, consider running DISM command "  -SpaceUsed $foldersize
                            }
                        }
                        "*SoftwareDistribution" {
                            Add-Recommendations -Category "Customer" -Recommendation "SoftwareDistribution is larger then 500MB, consider recreating the folder "  -SpaceUsed $foldersize
                        }
                        "*`$Recycle.Bin" {
                            Add-Recommendations -Category "Action" -Recommendation "Recycle Bin ($Folder) is larger then 500MB, consider deleting contents"  -SpaceUsed $foldersize
                        }
                    }
                }
               
               #if folder is in compressable folder list, recommend turning on compression
                if ((-NOT $FolderCompressed) -AND ($CompressableFolders -contains $Folder) -AND ($foldersize -gt $Limit)){
                    Add-Recommendations -Category "Action" -Recommendation "Turn on compression for $Folder" -SpaceUsed $foldersize
                    $FoldersToCompress.add($Folder)
                }

                $FolderTemp = New-Object PSObject -Property @{
                    "Name" = $folder
                    "Compressed" = $FolderCompressed
                    "Size (GB)" = $Foldersize
                }
                $Folders += $FolderTemp
        }else{
            #Folder doesnt exist so no point mentioning it 
        }
    }

    $Folders = $Folders | Sort-Object "Size (GB)" -Descending | Select-Object "Name","Compressed","Size (GB)"
    $output."Folders" =  ConvertTo-ASCII -Data $Folders -NoAddBlankLine

 

    ################################################
    #IIS installed
    ################################################

    #Find default logs - WebAdministration not always installed so we have to assume?
    #Import-Module WebAdministration
    #$IISLog = (Get-WebConfigurationProperty "/system.applicationhost/sites/sitedefaults" -name logfile.directory).Value
    #$LogLocation = $IISLog.replace("%SystemDrive%","C:")

    #assume default log location
    $LogLocation = "$DriveLetter\inetpub\logs\logfiles"

    $IISLogSummary = @()
    #if W3SVC is presnet on the server it assume IIS is installed
    If(Get-Service W3SVC -ErrorAction SilentlyContinue){
        #Check the default log location exists
        if(Test-Path $LogLocation -ErrorAction SilentlyContinue){
            #get all log folders
            $LogFolders = (Get-ChildItem $loglocation -recurse -ErrorAction SilentlyContinue -force | Where-Object {$_.PSIsContainer -eq $True} | Sort-Object)
            foreach ($folder in $LogFolders)
            {
                #get the log files
                $subFolderItems = Get-ChildItem $folder.FullName -ErrorAction SilentlyContinue -Force
                if($subFolderItems){
                    $count = $subFolderItems.count
                    $oldestfile = $subFolderItems | Sort-Object LastWriteTime | Select-Object -First 1
                    $oldestfiledate = (Get-Date $oldestfile.LastWriteTime -Format dd/MMM/yy) #use nice formate for date
                }else{
                    $count = "Folder empty"
                    $oldestfile = "Folder empty"
                }

                #total folder size
                $FolderSize = ($subFolderItems | Measure-Object -property length -sum).sum
                $RoundedFolderSize = $([Math]::Round(($FolderSize / 1GB),2))        
              
                #folder compressed
                $FolderCompressed = $null
                $FolderCompressed = Get-FolderCompressed -Folder $Folder.fullname

                $IISLogs = New-Object PSObject -Property @{
                    "Folder" = $Folder.FullName
                    "Size" = "$([Math]::Round(($FolderSize / 1GB),2)) GB"
                    "Compressed" = $FolderCompressed
                    "Oldest file" = $oldestfiledate
                    "Total files" = $subFolderItems.count
                }
                $IISLogSummary += $IISLogs

                #Recommendatons
                #compression
                if((-NOT $FolderCompressed) -AND ($IISLogs.Size -gt $Limit)){
                    Add-Recommendations -Category "Action" -Recommendation  "Turn compression on for $($Folder.fullname)" -SpaceUsed $RoundedFolderSize
                }
            
                #Oldest file older then 90 days
                if(($oldestfile.LastWriteTime) -lt (Get-Date).AddDays(-90) -AND ($IISLogs.Size -gt $Limit)){
                    Add-Recommendations -Category "Caution" -Recommendation  "Oldest file is older then 90 days, configure IISLogs for $($Folder.fullname)" -SpaceUsed $RoundedFolderSize
                }
            }
            $IISLogSummary = $IISLogSummary | Sort-Object Size -Descending | Select-Object "Folder","Size","Oldest file","Total files","Compressed"
            $output.IISLogSummary = ConvertTo-ASCII -Data $IISLogSummary -NoAddBlankLine
        }else{
            $output.IISLogSummary = "IIS installed but could not locate default log location" 
            Add-Recommendations -Category "Action" -Recommendation "IIS is running but cannot locate logs, check location and archive as required" -SpaceUsed 0 
        }
    }else{
        $output.IISLogSummary = "IIS not installed (W3SVC service not found)"
    }
    
    #################### Top 10 files - BEGIN ####################
    #region 

    #Maximum Disk size in GB to run get-childitem against.
    $Disklimit = 500
    #Maximun Number of files on disk approximatly to run get-childitem against.
    [Int]$FileLimit = 1000000

    [Switch]$RunTop10 = $true

    #Skip top 10 files if size of disk over 500Gb or unable to get disk size
    If ($Diskoutput."DiskSize (GB)" -gt $Disklimit)
    {
        $output."Top 10 files" += "File search is disabled as disk ($DriveLetter) is over $Disklimit`GB"
        $RunTop10 = $false
    }
    ElseIf ($null -eq $Diskoutput."DiskSize (GB)")
    {
        $output."Top 10 files" += "File search is disabled as unable to get size of disk ($DriveLetter)"
        $RunTop10 = $false
    }

    #Skips if number of files greater than a million ($FileLimit)
    If ($NumberofFiles -gt $FileLimit)
    {
        #Skips if number of files greater than a million ($FileLimit)
        #Dones't quite if unknown defaults to disksize and the way it will check.  
        $output."Top 10 files" += "Over 1 Million files found on disk (Approx files $NumberofFiles). Due to potential performance impact skipping check"
        $RunTop10 = $false 
    }

    If ($((Get-WMIObject Win32_OperatingSystem  -computername .).FreePhysicalMemory / 1MB) -lt 1.0) #/1MB gives you value in GB
    {
        #Check there is more than 1.5 GB of Memory free
        $output."Top 10 files" += "Less then 1GB RAM free on VM. Scanning files is memory intensive so skipping check"
        $RunTop10 = $false
    }

    #Name,SizeInMB,Directory 
    #http://blogs.msdn.com/b/powershell/archive/2009/11/04/why-is-get-childitem-so-slow.aspx
    #.NET4 update in powershell 3 makes get-childitem so much faster. it can cause memory issues in version 2 so we dont risk running it
    If ($RunTop10)
    {
        $GetChildItemJob1 = Start-JobTimeout -StringScriptblock "Get-ChildItem $DriveLetter\ -recurse -ErrorAction SilentlyContinue | Sort-Object Length -descending | select-object name,@{Name='Size (MB)';Expression={[Math]::Truncate(`$_.Length / 1MB)}},directory,LastWriteTime -First 5 -ErrorAction SilentlyContinue" -JobName "JobChildItemDrive" -TestJob -Timeout 300
        
        #Check if there was an error
        If ($GetChildItemJob1.JobError -eq $false)
        {
            #List of top 10 files
            $Top10Files = $GetChildItemJob1.JobOutput | Select-Object -Property * -ExcludeProperty PSComputerName,PSShowComputerName,RunspaceId 
            
            If($Top10Files)
            {
                $output."Top 10 files" = ConvertTo-ASCII -Data $Top10Files -NoAddBlankLine

                #Recommendations
                $BAKSize = (($Top10Files | Where-Object {$_.name -like "*.bak"}) | Measure-Object -property "Size (MB)" -sum).Sum
                if($BAKSize){
                    $BAKSizeRounded = $([Math]::Round($($BAKSize / 1024), 2))
                    Add-Recommendations -Category "Caution" -Recommendation  "BAK files found in top 10 files, zip and delete original bak" -SpaceUsed $BAKSizeRounded
                    Add-Recommendations -Category "Customer" -Recommendation  "BAK files found in top 10 files, consider enabling SQL backup compression in SSMS" -SpaceUsed $BAKSizeRounded
                }

                $LDFSize = (($Top10Files | Where-Object {$_.name -like "*.ldf"}) | Measure-Object -property "Size (MB)" -sum).Sum
                if($LDFSize){
                    $LDFSizeRounded = $([Math]::Round($($LDFSize / 1024), 2))
                    Add-Recommendations -Category "Action" -Recommendation  "LDF file found in top 10 files, are databases in full recovery mode with no backups configured?" -SpaceUsed $LDFSizeRounded
                }

                $TXTSize = (($Top10Files | Where-Object {($_.name -like "*.txt") -OR ($_.name -like "*.log") }) | Measure-Object -property "Size (MB)" -sum).Sum
                if($TXTSize){
                    $TXTSizeRounded = $([Math]::Round($($TXTSize / 1024), 2))
                    Add-Recommendations -Category "Customer" -Recommendation  "TXT/LOG file found in top 10 files, probably out of control log file, compress, archive, delete, as required" -SpaceUsed $TXTSizeRounded
                }

            }
            Else
            {
                $output."Top 10 files" = "Error Nothing returned: $($GetChildItemJob1.JobOutput) "
            }
        }
        Else
        {
            #Error return job error message
            $output."Top 10 files" += "Error: Unable to run Top to File check "
            $output."Top 10 files" += $GetChildItemJob1.JobOutput
        }
    }

    #endregion 
    ##################### Top 10 files - END #####################

    ################################################
    #SQL installed
    ################################################
    if(Get-Service "*MSSQLSERVER*" -ErrorAction SilentlyContinue){
        $SQLFiles = ($Top10Files | Where-Object {($_.name -like "*.ldf") -OR ($_.name -like "*.mdf")})
        if($SQLFiles){
            $Output."SQLSummary" = "SQL files found in top 10 files"
        }else{
            $Output."SQLSummary" = "No SQL files found in top 10 files"
        }

    }else{
        $Output."SQLSummary" = "SQL not installed on server"
    }

    #Remediation
    ###################### 

        #Did we recomend emptying recycle bin?
        if($Global:Recommendations -like "*recycle bin*"){
            $RecycleBinResults = Clear-RecycleBin $DriveLetter
            if($RecycleBinResults.'Megabytes Removed' -ne 0){
                $output.Remediation += "Recycle bin cleanup Result"
                $output.Remediation += (ConvertTo-ASCII -NoAddBlankLine -data ($RecycleBinResults | Select-Object "Megabytes Removed", "Items Removed")| out-string)
            }
            elseif($RecycleBinResults.'Items Removed' -eq $null)
            {
            }
            else{
                $output.Remediation += "Recycle bin cleanup Result"
                $output.Remediation += (ConvertTo-ASCII -NoAddBlankLine -data ($RecycleBinResults | Select-Object "ErrorMsg")| out-string)
            }
        }
        #Did we Recomend turning on compression?
        if($Global:Recommendations -like "*Turn on Compression for*"){
            $output.Remediation += "Enabling of NTFS Compression Result"
            $NTFSCompressionResults = Enable-NTFSCompression $FoldersToCompress
            if ($null -eq $NTFSCompressionResults.ErrorMsg){
                $output.Remediation += (ConvertTo-ASCII -NoAddBlankLine -data ($NTFSCompressionResults | Select-Object "Space Recovered (MB)")| out-string)
            }
            else{
                $output.Remediation += (ConvertTo-ASCII -NoAddBlankLine -data ($NTFSCompressionResults | Select-Object "ErrorMsg")| out-string)
            }
        }

    Try
    {
        $NumberofFilesAfter = $null
        $fsutilafter = fsutil fsinfo ntfsinfo $DriveLetter
        #Find line Mft Valid Data Length in the output of fsutil
        $MftValidDataLengthAfter = $fsutilafter | where-object {$_ -like "*Mft Valid Data Length*"}
        #split on the : and then remove white space to get the value
        $ValueAfter = $MftValidDataLengthAfter.Split(":")[-1] -replace '\s+',''
        $NumberofFilesAfter  = $ValueAfter / 1024 

        If (-Not ($NumberofFilesAfter -match '^\d+$'))
        {
            $NumberofFilesAfter = "Unknown Error"
        }
    }
    Catch
    {
        $NumberofFilesAfter = "Unknown Error" 
    }



        #After remediation output current disk status
        $VolumesAfter = (Get-WmiObject -Class Win32_LogicalDisk) | Select-Object Name, VolumeName, FreeSpace, DriveType, Size
        $DiskAfter = $VolumesAfter | where-object {$_.Name -like $DriveLetter}
        $CurrentDiskStatus = New-Object PSObject -Property @{
                    "DiskSize (GB)" = $([math]::Round($DiskAfter.Size/1GB,2))
                    "FreeSpace (GB)" = $([math]::Round($DiskAfter.FreeSpace/1GB,2))
                    "PercentFree"=”{0:N2}” -f $(($DiskAfter.FreeSpace/$DiskAfter.Size)*100)+”%” 
                    "Number of Files (Approx)" = $NumberofFilesAfter
                    }

    If($RecycleBinResults.'Items Removed' -ne $null -or $RSPKGsResults."Space Recovered (GB)" -ne $null -or $NTFSCompressionResults."Space Recovered (GB)" -ne $null)
    {
        $Output.Remediation += "Disk Status after automated remediation"
        $output.Remediation += (ConvertTo-ASCII -NoAddBlankLine -data ($CurrentDiskStatus) | out-string)
        $output.Remediation += "- Automated Remediation Log Location: $($LogFile)"
        $output.Remediation += ""
    }
    else
    {
    $Output.Remediation += "No automated remediation actions were executed."
    }

        #Get OS Information for final output
        $OSType = (Get-CimInstance Win32_OperatingSystem).Caption
        $LocalIpAddress = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
        $OSInfo = New-Object PSObject -property @{
                 "VM"  = "$env:computername"
                 "OS" =   "$OSType"
                 "IP" = "$LocalIpAddress"
                }

    ################################################
    #Output
    ################################################

    #Private Comment for Diskspace diagnostics
    if ($DiskAfter.FreeSpace -lt $FreespaceThreshold)
    {

    #Generate a pretty output for the ticket
    $OutputReport = @()
    $OutputReport += "[TICKET_UPDATE=PRIVATE]"
    $OutputReport += "[TICKET_STATUS=ALERT RECEIVED]"  
    $OutputReport += "The alert is still active and requires intervention. Please review the low disk report below and troubleshoot accordingly:`n "  
    $OutputReport += "Virtual Machine  : $($OSInfo.VM)"
    $OutputReport += "Operating System : $($OSInfo.OS)"
    $OutputReport += "IPv4 Address     : $($OSinfo.IP)`n"
        
    $OutputReport += "Disk Summary: $($DriveLetter)" 
    $OutputReport += $($output."Disk" | out-string)
    
    $OutputReport += "Top 5 largest files:"
    $OutputReport += $($output."Top 10 files" | out-string)
    
    $OutputReport += "User profiles over $Limit GB:"
    $OutputReport += $($output."Large profiles" | out-string)
    
    $OutputReport += "Pagefile:"
    $OutputReport += $($output."Pagefile" | out-string)
    
    $OutputReport += "Common large folders:"
    $OutputReport += $($output."Folders" | out-string)
    
    $OutputReport += "IIS Log Summary:"
    $OutputReport += $($output."IISLogSummary" | out-string)
    
    $OutputReport += "SQL Summary:"
    $OutputReport += $($output."SQLSummary" | out-string)

    $OutputReport += "Remediation results:"
    $OutputReport += "$($(ConvertTo-ASCII -NoAddBlankLine -EscapeSlash -data $output.Remediation) | out-string)"
    }
    #Public Auto close comment and threshold
    elseif ($DiskAfter.FreeSpace -gt $FreespaceThreshold)
    {
    $OutputReport = @()
    $OutputReport += "[TICKET_UPDATE=PUBLIC]"
    $OutputReport += "[TICKET_STATUS=CONFIRM SOLVED]"
    $OutputReport += "Hello Team,`n`nOur Smart Ticket engine has detected that available free diskspace is above 1GB for the $($DriveLetter) drive. Below is a summary of any actions taken, including emptying the Recycle Bin, compressing logs.`n"

    $OutputReport += "Virtual Machine  : $($OSInfo.VM)"
    $OutputReport += "Operating System : $($OSInfo.OS)"
    $OutputReport += "IPv4 Address     : $($OSinfo.IP)`n"

    $OutputReport += "Disk Status (At time of alert being triggered)"
    $OutputReport += $($output."Disk" | out-string)

    $OutputReport += "$($(ConvertTo-ASCII -NoAddBlankLine -EscapeSlash -data $output.Remediation) | out-string)"
    $OutputReport += "As the free disk space is now above the above 1% alert threshold for the C: drive, we will mark this ticket as 'Confirm Solved'. Although the alert has cleared, please review your disk usage and ensure you have sufficient space on VM: $($OSInfo.VM) for your solution to run smoothly. If you have any questions, or require further assistance, please contact support"
    }
    else
    {
    $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
    $OutputReport = @()
    $OutputReport = "Script failure: $($ErrMsg)"
    } 
          
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

#Output Report for Azure Smart Tickets
(Resolve-DiskSpaceAlert -Remediate Y -Force).Report | Format-List