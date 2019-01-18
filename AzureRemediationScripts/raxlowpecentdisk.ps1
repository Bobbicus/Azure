<#
    .SYNOPSIS
    Smart Ticket remedation script for Low Disk Space.
       
    .DESCRIPTION
    Ingests JSON payload and based on $DriveLetter variable, analyses Disk statistics and provides an output accordingly.

    Supported: Yes
    Keywords: azure,diskspace,low,smarttickets
    Prerequisites: No
    Makes changes: No

    .EXAMPLE
    Full command:  .\raxlowpecentdisk.ps1
    Description: Smart Ticket script - payload aware.
       
    .OUTPUTS
    Example output:
 
    Hello Team,

    Our Smart Ticket engine has detected that available free diskspace is above 1% for the D: drive. No remediation action has been taken.

    Virtual Machine  : jumpy
    Operating System : Microsoft Windows Server 2012 R2 Datacenter
    IPv4 Address     : 172.16.195.6
    Resource Group   : neu-rsg-clt-prd
    Subscription     : c79f1783-c8cf-4575-8cea-f28axe1c50x7

    Disk Status:
     +---------------+----------------+--------------------------+-------------+
     | DiskSize (GB) | FreeSpace (GB) | Number of Files (Approx) | PercentFree | 
     |=========================================================================|
     | 70            | 69.36          | 256                      | 99.08%      | 
     +---------------+----------------+--------------------------+-------------+

    As the free disk space is now above the above 1% alert threshold for the D: drive, we will mark this ticket as 'Confirm Solved'. Although the alert has cleared, please review your disk usage and ensure you have sufficient space on VM: jumpy for your solution to run smoothly. If you have any questions, or require further assistance, please contact Rackspace Support to discuss further.

    Kind regards,

    Microsoft Azure Engineer
    Rackspace Toll Free: (800) 961-4454

        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0

    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Oliver Hurn        :: 01-APR-2017 :: XX-XXX   :: Bob Larkin  :: Release
    1.1     :: Oliver Hurn        :: 19-JUL-2017 :: XX-XXX   :: Bob Larkin  :: Changed Diagnostic report Output
#>

   #Script Uri
    Param(
    [Parameter(Mandatory=$false)]$PayloadUri
    )

Function Get-DiskSpaceAlert
{
    try
    {

    #region Testing
    #uncomment for testing
    #$object = ConvertFrom-Json "$(get-content -Path C:\rs-pkgs\lowpecentdisk.json)"
    
    #endregion

    #region Script Variables
    #Ingest the payload
    $object = Invoke-RestMethod -Uri $PayloadUri

    #Payload variables
    $DriveLetter = $object.Disk
    
    #Free space Threshold in %
    $Threshold = '1'

    #Ticket Signature
    $ticketSignature = "Kind regards,`n`nSmart Ticket Automation`nRackspace Toll Free (US): 1800 961 4454`n                    (UK): 0800 032 1667"  

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
       Wiki = https://one.rackspace.com/display/IAW/ConvertTo-ASCII

       Version Table:
        Version :: Author         :: Live Date   :: JIRA       :: QC             :: Description
        -----------------------------------------------------------------------------------------------------------
        1.0     :: Mark Wichall   :: 03-MAR-2016 :: IAWW-000   :: Martin Howlett :: Release
        1.1     :: Mark Wichall   :: 07-MAR-2017 :: IAWW-469   :: Martin Howlett :: Update code to current standard and suggestions John Luikart made
        1.2     :: Mark Wichall   :: 16-MAR-2017 :: IAWW-469   :: Martin Howlett :: fixed formating to add option to escape \ for wham templates 
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

    #################### Output psobject - BEGIN ####################
    #region 

    $Output = New-Object PSObject -Property @{
        "Disk" = ""
        "Top 10 files" = ""
    }

    #endregion 
    ##################### Output psobject - END #####################

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

    #Creates Disk Output showing DiskSize, Freespace, PercentFree and Number of Files
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

    #################### Top 10 files - BEGIN ####################
    #region 

    #Maximum Disk size in GB to run get-childitem against.
    $Disklimit = 1024

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

    If ($((Get-WMIObject Win32_OperatingSystem  -computername .).FreePhysicalMemory / 1MB) -lt 0.25) #/1MB gives you value in GB
    {
        #Check there is more than 250MB of Memory free
        $output."Top 10 files" += "Less then 250MB RAM free on VM. Scanning files is memory intensive so skipping check"
        $RunTop10 = $false
    }

    #Name,SizeInMB,Directory 
    #http://blogs.msdn.com/b/powershell/archive/2009/11/04/why-is-get-childitem-so-slow.aspx
    #.NET4 update in powershell 3 makes get-childitem so much faster. it can cause memory issues in version 2 so we dont risk running it
    If ($RunTop10)
    {
        #Run job to get Top 10 Largest files on the disk
        $GetChildItemJob1 = Start-JobTimeout -StringScriptblock "Get-ChildItem $DriveLetter\ -recurse -ErrorAction SilentlyContinue | Sort-Object Length -descending | select-object name,@{Name='Size (MB)';Expression={[Math]::Truncate(`$_.Length / 1MB)}},directory,LastWriteTime -First 10 -ErrorAction SilentlyContinue" -JobName "JobChildItemDrive" -TestJob -Timeout 300
        
        #Check if there was an error
        If ($GetChildItemJob1.JobError -eq $false)
        {
            #List of top 10 files
            $Top10Files = $GetChildItemJob1.JobOutput | Select-Object -Property * -ExcludeProperty PSComputerName,PSShowComputerName,RunspaceId
            
            #Add Top10Files variable to Output 
            $output."Top 10 files" = ConvertTo-ASCII -Data $Top10Files -NoAddBlankLine
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
        
    

    #endregion 
    ##################### Top 10 files - END #####################


    #Get OS Information for final output
    $OSType = (Get-CimInstance Win32_OperatingSystem).Caption
    $LocalIpAddress = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
    $OSInfo = New-Object PSObject -property @{
                "VM"  = "$env:computername"
                "OS" =   "$OSType"
                "IP" = "$LocalIpAddress"
            }

    #Generate a output for the ticket
    #Private Comment for Diskspace diagnostics
    #If Diskspace % is above 1% then output diagnostics report
    if ($Diskoutput.PercentFree -lt $Threshold)
    {
    $OutputReport = @()
    $OutputReport += "[TICKET_UPDATE=PUBLIC]"
    $OutputReport += "[TICKET_STATUS=ALERT RECEIVED]"
    $OutputReport += "Hello Team,`n`nThe alert is still active and requires a Racker to review the automated output and troubleshoot accordingly. In the meantime, please feel free to review the 'Top 10 largest Files' report and help us recover the necessary disk space above the $($Threshold)% threshold:`n "  
    $OutputReport += "Virtual Machine  : $($OSInfo.VM)"
    $OutputReport += "Operating System : $($OSInfo.OS)"
    $OutputReport += "IPv4 Address     : $($OSinfo.IP)"
    $OutputReport += "Resource Group   : $($object.ResourceGroup)"
    $OutputReport += "Subscription     : $($object.SubscriptionId)`n"
        
    $OutputReport += "Disk Summary: $($DriveLetter)" 
    $OutputReport += $($output."Disk" | out-string)
    
    $OutputReport += "Top 10 largest files:"
    $OutputReport += $($output."Top 10 files" | out-string)

    $OutputReport += "$($ticketSignature)"
    }

    #Public Auto close comment and threshold is above 1% freespace
    elseif ($Diskoutput.PercentFree -gt $Threshold)
    {
    $OutputReport = @()
    $OutputReport += "[TICKET_UPDATE=PUBLIC]"
    $OutputReport += "[TICKET_STATUS=CONFIRM SOLVED]"
    $OutputReport += "Hello Team,`n`nOur Smart Ticket engine has detected that available free diskspace is above $($Threshold)% for the $($DriveLetter) drive. No remediation action has been taken.`n"

    $OutputReport += "Virtual Machine  : $($OSInfo.VM)"
    $OutputReport += "Operating System : $($OSInfo.OS)"
    $OutputReport += "IPv4 Address     : $($OSinfo.IP)"
    $OutputReport += "Resource Group   : $($object.ResourceGroup)"
    $OutputReport += "Subscription     : $($object.SubscriptionId)`n"

    $OutputReport += "Disk Status:"
    $OutputReport += $($output."Disk" | out-string)

    $OutputReport += "As the free disk space is now above the above $($Threshold)% alert threshold for the $($DriveLetter) drive, we will mark this ticket as 'Confirm Solved'. Although the alert has cleared, please review your disk usage and ensure you have sufficient space on VM: $($OSInfo.VM) for your solution to run smoothly. If you have any questions, or require further assistance, please contact Rackspace Support to discuss further.`n`n"
    $OutputReport += "$($ticketSignature)"
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

(Get-DiskSpaceAlert).Report | Format-List