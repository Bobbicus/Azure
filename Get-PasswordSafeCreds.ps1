<#
    .SYNOPSIS
    Get VM credentials from passwordsafe 
       
    .DESCRIPTION
    Full description: Get VM credentials from passwordsafe, display VM IP,Passwords and username.  User has the option to provide ticket number so the script can find the subscription ID and VM Name, 
    they can input subscription ID and VM Name or lastyly they can enter just the VM and the script will work out the environement from dev,staging, prod etc and search the relevant subscription.

    supported: Yes
    Prerequisites: CTKCore
    Makes changes: No
    .EXAMPLE
    Full command: <example command>
    Description: <description of what the command does>
    Output:
       
    .OUTPUTS
    Name             : [user.name@rackspace.co.uk]
    Account          : user.name@rackspace.co.uk
    SubscriptionName : Azure Sub Name
    TenantId         : 1234456789abcdefg
    Environment      : AzureCloud


    VMname          : EUWSSVM999
    VMResourceGroup : Azure-RG-NUM
    VMPrivateIP     : 1.2.3.4
    VMOS            : WindowsServer 2012-R2-Datacenter
    VMSubscription  : 

    Username      : username
    Category      : euwss 999
    Full username : domain\user
    Password      : MadeUpPassword123

    Username      : username
    Category      : euwss 999
    Full username : domain\user
    Password      : MadeUpPassword123

    Username      : username
    Category      : euwss 999
    Full username : domain\user
    Password      : MadeUpPassword123


        
    .NOTES
    Minimum OS: 2012 
    Minimum PoSh: 4.0
    Version Table:
    Contribution: Patrick Smith - Get-VMInfoFromTicket function

    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 10-Mar-2018 ::          ::             :: Release
#>

<#Use Tokx module to get token
$GetToken = Get-RackerToken
$Token = $GetToken.XAuthToken.'x-auth-token'
#>
#Run the menu fucntion to ask user how they want to get the VMName and subscription

#region Get-VMInfoFromUser
function Get-VMInfoFromUser
{
  Try
  {
      $VMnameFull = Read-host "Enter VM Name"
      $subscriptionID = Read-host "Enter Subscription ID"
      $VMName = $null
      if ($VMnameFull.Split(".").Count -gt 1)
      {
            $VMName =  $VMnameFull.Split(".")[0]
      }
      if (! $VMName)
      {           
          $item = New-Object PSObject
          $item | Add-member -MemberType NoteProperty -Name "Name" -Value $VMNameFull
          $item | Add-member -MemberType NoteProperty -Name "SubscriptionID" -Value $subscriptionID
          return $item
      }
      else
      {
          $item = New-Object PSObject
          $item | Add-member -MemberType NoteProperty -Name "Name" -Value $VMName
          $item | Add-member -MemberType NoteProperty -Name "FullName" -Value $VMNameFull
          $item | Add-member -MemberType NoteProperty -Name "SubscriptionID" -Value $subscriptionID
          return $item
      }

  }
  Catch
  {
      Return "ERROR : Unhandled exception :: (Line: $($_.InvocationInfo.ScriptLineNumber) Line: $($_.InvocationInfo.Line) Error message: $($_.exception.message))"
  }
}
#endregion




#region Get-VMInfoFromTicket
function Get-VMInfoFromTicket
{
#Get-VMIP Written by Patrick Smith
    Param
    (
        # Param1 Provide the Ticket# from CORE
        [Parameter(Mandatory=$True)]
        [string]$ticket
    )
        Begin
        {
            if ($ticket -eq $null) {$ticket = read-host "Provide ticket#" }
        }
        Process
        {
    
            $message = (Get-CoreTicketMessage -ID (((Get-CoreTicketContents -ticket $ticket).messages[0]).load_value)).text
            $subscriptionID = ($message.Split("`n") | where {$_ -like "*`"SubscriptionId`":*"}).split("`"")[-2]
            if ($subscriptionID -eq "SubscriptionID"){
                "Ticket does not contain a valid subscription ID"#search through all EY subscriptions for the VM
            }
            $VMnameFull = $null
            #flipped the check as entity name was not matching 
            $VMnameFull = ($message.Split("`n") | where {$_ -like "*`"Computer`":*"}).split("`"")[-2]
        
        
            if (!($VMnameFull)){
                $VMnameFull = ($message.Split("`n") | where {$_ -like "*`"Entity Name`":*"}).split("`"")[-2] 
            }
            #change to set context ?? BOB 
    
            #Login-MSCloudSubscription -subscription (Get-MSCloudSubscription -AzureSubscriptionId $subscriptionID)
        
            if ($VMnameFull.Split(".").Count -gt 1){
                $VMName =  $VMnameFull.Split(".")[0]
            }

            if (! $VMName)
            {           
                $item = New-Object PSObject
                $item | Add-member -MemberType NoteProperty -Name "Name" -Value $VMNameFull
                $item | Add-member -MemberType NoteProperty -Name "SubscriptionID" -Value $subscriptionID
                return $item
            }
            else
            {
                $item = New-Object PSObject
                $item | Add-member -MemberType NoteProperty -Name "Name" -Value $VMName
                $item | Add-member -MemberType NoteProperty -Name "FullName" -Value $VMNameFull
                $item | Add-member -MemberType NoteProperty -Name "SubscriptionID" -Value $subscriptionID
                return $item
            }
        }
}


#region search
#Not yet working.  Need to add logic to search all subscrscriptions for VM

function Get-VMfromSearch
{
            
        $VMnameFull = $null
        $VMnameFull = Read-host "Enter VM Name without domain name"

        #This one letter determines environement D=dev,Q=QA,S=Staging etc we then make an array of all tehe relevant subs
        $VMEnvironment = $VMnameFull.Substring(4,1)
        if ($VMEnvironment -eq "D")
        {
            $SubEnvironment = "Dev"
            $SearchSubscriptions = ("c935b83e-cb20-4a23-878a-8e57a53cafa3","8d41ac3a-a9e5-48fe-bdc7-13a75f985222")


        }
        elseif ($VMEnvironment -eq "Q")
        {
            $SubEnvironment = "QA"
            $SearchSubscriptions = ("8b2e6670-8681-4fc3-82f5-a8fd4cbb44f0","8b2e6670-8681-4fc3-82f5-a8fd4cbb44f0")
      

        }

        elseif ($VMEnvironment -eq "S")
        {
            $SubEnvironment = "Staging"
            $SearchSubscriptions = ("49324df2-a17e-4d85-9c0c-c3868007820e","a23eeff5-c9f8-4fdb-ad69-4098b319b953","aed869a9-c316-41c3-a8f4-7f2d0b1cc30a","1a43f539-e78a-4350-9dd6-2d97e421d17f","34b0695e-fc1d-44a2-b98f-7052fde1052f","3b1021f1-ba9d-4212-8f88-be6e62d93a7c")
 
        }


        elseif ($VMEnvironment -eq "P")
        {
            $SubEnvironment = "Production"
            $SearchSubscriptions = ("0c3df843-e9ad-4247-a492-bbcbe680ef14","6979160c-04b0-405c-bdd0-34587b0d5fdc","cffbdc5d-c42a-497c-8e02-7836d212bec2","8caa458c-7e14-4018-ae26-4a188e7cf131","38779e91-f4b7-4a5c-a46a-15cccfe74f79","c8f4c5f1-9477-4701-b1b3-0908558fca75")

        }    
        else
        {
             Write-host "Environment not found, check spelling of VM name and try again." -ForegroundColor Red
             return $null
        }

      Write-Host "Searching $SubEnvironment subscriptions for VM $VMnameFull please wait this could take a while" -ForegroundColor Yellow
      foreach ($Sub in $SearchSubscriptions)
      {
            Set-AzureRmContext $Sub | Out-Null
            $resource = Find-AzureRmResource -ResourceNameEquals $VMnameFull
            $item = New-Object PSObject
            $item | Add-member -MemberType NoteProperty -Name "Name" -Value $VMNameFull
            $item | Add-member -MemberType NoteProperty -Name "SubscriptionID" -Value $resource.subscriptionId
            return $item
      }
}

#endregion

function Get-VMDetailsFromAzure
{

        Process
        {
            $VMName = $VMInput.Name
            $subscriptionid = $VMInput.subscriptionID
            Set-AzureRmContext $subscriptionID
            $resource = Find-AzureRmResource -ResourceNameEquals $VMname
                #$VMName = "USNCPVIM020AD01"
                #$SubscriptionID = "8caa458c-7e14-4018-ae26-4a188e7cf131"
                #$VM = Get-AzureRmVM | Where-Object {$_.Name -eq $VMName} 
                $vm = Get-AzureRmVM -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
                $nid = $vm.NetworkProfile.NetworkInterfaces.id
                #$RGName = $nid.Split("/")[4]
                $ni = Get-AzureRmNetworkInterface -Name $nid.Split("/")[-1] -ResourceGroupName $nid.Split("/")[4]
                $ip = ($ni.IpConfigurations).PrivateIpAddress
                $OSSKU = "$($vm.StorageProfile.ImageReference.Offer)" + " " + "$($vm.StorageProfile.ImageReference.SKU)"
        
        }
        End
        {
            $properties = [ordered]@{
                VMname = $vm.Name
                VMResourceGroup = $vm.ResourceGroupName
                VMPrivateIP = $ip
                VMOS = $OSSKU
                VMSubscription = $subscriptionID
            }
            $vmreport = New-Object -TypeName PSObject -Property $properties
            $vmreport =  $vmreport
            return $vmreport
        }

}

#endregion
#Bob -do IO need this, this is not used the SSO ? 

#region Process - Phase - Credential

function Get-AzureRsCredential {
        Begin 
        {
            Write-Verbose -Message "Initiating internal function AzureRsCredential"
            #Write-Progress -Activity "Updating Credentials in Progress" -Status "10% Complete:" -PercentComplete 10
        }

        Process 
        {
            If (!$Credential) 
            {
                $Credential = Get-Credential -Message "Please enter your Rackspace SSO credentials: "
            }
        }
    
        End 
        {
            Write-Verbose -Message "Initiating internal function AzureRsCredential completed"
            #Write-Progress -Activity "Updating Credentials in Progress" -Status "15% Complete:" -PercentComplete 15
            return $Credential
        }

}


#Login to Azure
function Get-AzureRsAuthentication {

    Begin 
    {
        Write-Verbose -Message "Initiating internal function AzureRsAuthentication"
        #Write-Progress -Activity "Updating Credentials in Progress" -Status "30% Complete:" -PercentComplete 30
    }

    Process {
        Try {
            $Context = Get-AzureRmContext
            If ($Context.Account -eq $null) { Login-AzureRmAccount -ErrorAction Stop | Out-Null 
            }
            
            return $Context
            
        }

        Catch 
        {
            Write-Verbose -Message "Initiating internal function AzureRsAuthentication failed"
            Write-Error -Message $_.Exception.Message
            Break
        }    
    }

    End {
        Write-Verbose -Message "Initiating internal function AzureRsAuthentication completed"
        #Write-Progress -Activity "Updating Credentials in Progress" -Status "35% Complete:" -PercentComplete 35
       
    }

}
#endregion

#region Process - Phase 2 - PasswordSafe - Token
function Get-AzureRsPasswordSafeToken {
    
    Param (
        [Parameter()]
        [pscredential]$Credential
    )
    Try
    {
                
            $User = $Credential.Username
            $Pass = $Credential.GetNetworkCredential().Password
            #Write-Verbose -Message "Initiating internal function AzureRsPasswordSafeToken"
            #Write-Progress -Activity "Updating Credentials in Progress" -Status "40% Complete:" -PercentComplete 40

            # Comment: Check PasswordSafe access
            #Invoke-WebRequest -Uri "https://passwordsafe.corp.rackspace.com" -TimeoutSec 3 -Verbose:$false | Out-Null
 
       
            $Uri = "https://identity-internal.api.rackspacecloud.com/v2.0/tokens"
            $Headers = @{}
            $Headers.Add("Content-Type", "application/json")

            

            $Creds = New-Object -TypeName psobject
            $Creds | Add-Member -MemberType NoteProperty -Name "username" -Value $User
            $Creds | Add-Member -MemberType NoteProperty -Name "password" -Value $Pass
            

            $Domain = New-Object -TypeName psobject
            $Domain | Add-Member -MemberType NoteProperty -Name "name" -Value "Rackspace"

            $Auth = New-Object -TypeName psobject
            $Auth | Add-Member -MemberType NoteProperty -Name "RAX-AUTH:domain" -Value $Domain
            $Auth | Add-Member -MemberType NoteProperty -Name "passwordCredentials" -Value $Creds

            $Body = New-Object -TypeName psobject
            $Body | Add-Member -MemberType NoteProperty -Name "auth" -Value $Auth

            $Response = Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Body ($Body | ConvertTo-Json) -Verbose:$false
            $Token = $Response.access.token.id
            return $Token
        
    }
    Catch
    {
        Return "ERROR : Unhandled exception :: (Line: $($_.InvocationInfo.ScriptLineNumber) Line: $($_.InvocationInfo.Line) Error message: $($_.exception.message))"
    }
    
}


#endregion
function Get-PasswordSafeCreds
{
    Try
    {
        $VMName = $VMInput.Name
        #text/html,application/json,application/xml  etc check api wiki for details on a per endpoint basis
        $Header = @{
            "X-Auth-Token" = $Token
            "Accept" = "application/json"
        }

        #Get all visibile projects from Password safe, this shows you any projects you would see on site
        $Projects = Invoke-RestMethod -Uri "https://passwordsafe.corp.rackspace.com/projects" -Headers $Header
        $ProjectsDetails = $Projects.project
        
        #View cheat sheet for more info of VMname breakdown https://one.rackspace.com/pages/viewpage.action?title=Standards+and+Practices+-+EY+Support+Cheat+Sheet&spaceKey=enterprisesupport
        #The first four charactes relate to the location USSC = US South Central
        $VMLocation = $VMName.Substring(0,4)
        #This one letter determines environement D=dev,Q=QA,S=Staging etc 
        $VMEnvironment = $VMName.Substring(4,1)
        #This will always be VIM virtual machine for this script
        $ResourceType = $VMName.Substring(5,3)
        #This relates to the tenant resource 001-010 etc
        $VMResourceNumber = $VMName.Substring(8,3)
        #Trim off any leading zeros
        
        
        #VM type is last part SQL,AD01,IIS01 
        $VMType = $VMName.Substring(11)

        $VMName = $VMinfoFinal.VMname
        $VMNameDomName = $VMInput.FullName

        $ManagedDomains = @("eymsstg","eymsqa","eymsdev","eyms")
        if ($VMNameDomName -ne $null -and $VMNameDomName.Split(".").Count -gt 1)
        {
            $Domain = $VMNameDomName.Split(".")[-2]
        }
        
        if ($ManagedDomains -contains $Domain)
        {
            
            $category = $Domain
            if($VMType -like "AD*")
            {
                $ProjectName = "4815968 (Managed Services) : MT - Domain Tier 0 Credentials"
                #https://passwordsafe.corp.rackspace.com/projects/11819
            }
            else
            {
                $ProjectName = "4815968 (Managed Services) : MT - Domain Tier 1 Credentials"
                #https://passwordsafe.corp.rackspace.com/projects/18726
            }
        }
        else
        {
            [int]$VMResourceNumber1 = $VMResourceNumber1
            $VMResourceNumber1 = $VMResourceNumber.TrimStart("0")
            #Pick out a specific project
            
            <#
            4815968 (Managed Services) : ST - Tenant 001-010
            4815968 (Managed Services) : ST - Tenant 011-020
            4815968 (Managed Services) : ST - Tenant 021-030
            4815968 (Managed Services) : ST - Tenant 031-040
            4815968 (Managed Services) : ST - Tenant 041-050
            4815968 (Managed Services) : ST - Tenant 051-060
            4815968 (Managed Services) : ST - Tenant 061-070
            4815968 (Managed Services) : ST - Tenant 071-080
            4815968 (Managed Services) : ST - Tenant 081-090
            4815968 (Managed Services) : ST - Tenant 091-100
            4815968 (Managed Services) : ST - Tenant 291-300
            4815968 (Managed Services) : ST - Tenant 891-900
            #>
            #Based on the $VMResourceNumber extracted from VMname find teh right project
            #$VMResourceNumber = "020"
            if($VMResourceNumber1 -lt 11)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 001-010"
            }
            if($VMResourceNumber1 -gt 10 -and $VMResourceNumber1 -lt 21)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 011-020"
            }
            if($VMResourceNumber1 -gt 20 -and $VMResourceNumber1 -lt 31)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 021-030"
            }
            if($VMResourceNumber1 -gt 30 -and $VMResourceNumber1 -lt 41)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 031-040"
            }
            if($VMResourceNumber1 -gt 40-and $VMResourceNumber1 -lt 51)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 041-050"
            }
            if($VMResourceNumber1 -gt 50 -and $VMResourceNumber1 -lt 61)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 051-060"
            }
            if($VMResourceNumber1 -gt 60-and $VMResourceNumber1 -lt 61)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 061-070"
            }
            if($VMResourceNumber1 -gt 70 -and $VMResourceNumber1 -lt 71)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 071-080"
            }
            if($VMResourceNumber1 -gt 80 -and $VMResourceNumber1 -lt 91)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 081-090"
            }
            if($VMResourceNumber1 -gt 90 -and $VMResourceNumber1 -lt 101)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 091-100"
            }
            if($VMResourceNumber1 -gt 290 -and $VMResourceNumber1 -lt 301)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 291-300"
            }
            if($VMResourceNumber1 -gt 890 -and $VMResourceNumber1 -lt 901)
            {
                $ProjectName = "4815968 (Managed Services) : ST - Tenant 891-900"
            }
            $category = $VMLocation+$VMEnvironment+" "+$VMResourceNumber


        }
        $ChosenProject = $ProjectsDetails | Where-object {$_.name -eq $ProjectName}
        $ID = $ChosenProject.ID

        #write-host $ID
        #write-host $ChosenProject
        $Proj = Invoke-RestMethod -Uri "https://passwordsafe.corp.rackspace.com/projects/$ID" -Headers $Header

        #Get the project ID which we need for the Next call


        #Get credentials for a specific project 
        #$Creds = Invoke-RestMethod -Uri "https://passwordsafe.corp.rackspace.com/projects/20944/credentials" -Headers $Header
        #Using 0 at end gets all passwords for that project otherwise you only see a subset.  think there is a limit of 25 sop you could loop through each one
        $Creds = Invoke-RestMethod -Uri "https://passwordsafe.corp.rackspace.com/projects/$ID/credentials.json?page=0" -Headers $Header
 

        #Work out if it is a Domain controller or member server by checking for AD in VM name
        if ($VMType -like "AD*")
        {
            $usernameprefix = "raxadmin0*"
        }
        else
        {
            $usernameprefix = "raxadmin1*"
        }
        $category = $category.ToLower()
     
        #expand out the note property
        $CredDetails = $Creds.Credential
        $CredOutput  = @()
        if ($ManagedDomains -contains $Domain)
        {
          
            foreach ($User in $CredDetails)
            {
                    if ($User.username -like $usernameprefix -and $User.category -like "*"+$Category+"*")#$category)
                    {
                        #Write-host "`nusername:"$User.username
                        #Write-host "category:"$User.category                  
                        $UserNameFinal = $User.username
                        $FullDomainName = $Domain+"\"+$UserNameFinal
                        #Write-host "Full username:"$FullDomainName
                        #Write-host "password:"$User.password
                        $Output = New-Object PSObject
                        $Output | Add-member -MemberType NoteProperty -Name "Username" -Value $UserNameFinal
                        $Output | Add-member -MemberType NoteProperty -Name "Category" -Value $User.category 
                        $Output | Add-member -MemberType NoteProperty -Name "Full Username" -Value $FullDomainName
                        $Output | Add-member -MemberType NoteProperty -Name "Password" -Value $User.password
                        $CredOutput +=$Output
                    }

            }
            
        }

        else
        {


            foreach ($User in $CredDetails)
            {
                    if ($User.username -like $usernameprefix -and $User.category -eq $Category)
                    {
                        #Write-host "`nusername:"$User.username
                        #Write-host "category:"$User.category
                        #Write-host "domain:"$User.Hostname
                        $Hostname = $User.Hostname.split(".")
                        $Domain = $Hostname[0]
                        $UserNameFinal = $User.username
                        $FullDomainName = $Domain+"\"+$UserNameFinal
                        #Write-host "Full username:"$FullDomainName
                        #Write-host "password:"$User.password
                        $Output = New-Object PSObject
                        $Output | Add-member -MemberType NoteProperty -Name "Username" -Value $UserNameFinal
                        $Output | Add-member -MemberType NoteProperty -Name "Category" -Value $User.category 
                        $Output | Add-member -MemberType NoteProperty -Name "Full username" -Value $FullDomainName
                        $Output | Add-member -MemberType NoteProperty -Name "Password" -Value $User.password
                        $CredOutput +=$Output
                   
                    }

            }
            
        }
        return $CredOutput
    }
    Catch
    {
        Return "ERROR : Unhandled exception :: (Line: $($_.InvocationInfo.ScriptLineNumber) Line: $($_.InvocationInfo.Line) Error message: $($_.exception.message))"
    }

}


<#

#Bob Get-Azure resource group
                              
#I am only doing shared tenant for now as these are ones that are in Password safe . Could use this section to get IP of any EY VM




$STGSubscriptions = ("0c3df843-e9ad-4247-a492-bbcbe680ef14","cffbdc5d-c42a-497c-8e02-7836d212bec2","8caa458c-7e14-4018-ae26-4a188e7cf131")


            "EY-MS-AP-STG-37767682", `
            "EY-MS-AP-STG-ST1-37767682", `
            "EY-MS-EMEIA-STG-35363712", `
            "EY-MS-EMEIA-STG-ST1 - 35363712", 
            "EY-MS-US-STG-34286012", `
            "EY-MS-US-STG-ST1 - 35363712", `
            "EY-MS-AP-PROD-37767682", `
            "EY-MS-AP-PROD-ST1-37767682", `
            "EY-MS-EMEIA-PROD-35363712", `
            "EY-MS-EMEIA-PROD-ST1 - 35363712", `
            "EY-MS-US-PROD-34286012", `
            "EY-MS-US-PROD-ST1-35363712"
   

  'Tier-0' = @{
                    'raxadmin0-1'
                    'raxadmin0-2' 
                    'raxadmin0-3' 
                }
                'Tier-1' = @{
                    'raxadmin1-1'
                    'raxadmin1-2' 
                    'raxadmin1-3'                    
                }
#>




function Get-Menu 
{
    Try
    {

        #Get user input to check intial state, end state of VM and return VMs to original state
        Write-Host  "1. Enter Ticket Number:" -ForegroundColor Cyan
        Write-Host  "2. Enter Device and Subscription" -ForegroundColor Cyan
        Write-Host  "3. Search using device (this can take some time)" -ForegroundColor Cyan
        Write-Host  "4. Enter 4 or Q to quit" -ForegroundColor Cyan

        $UserInput = read-host "Choose how to find the device details 1, 2 or 3"


        If ($UserInput -eq 1)
        {
            Get-VMInfoFromTicket
        }
        elseIf ($UserInput -eq 2)
        {
            Get-VMInfoFromUser
        }
        elseIf ($UserInput -eq 3)
        {
            Get-VMfromSearch
        }
        elseIf ($UserInput -eq 4 -or $UserInput -eq "Q")
        {
            Break
        }
        else
        {
            Write-host "Not valid input" -ForegroundColor Red
            Get-menu
        }
    }
    Catch
    {
        Return "ERROR : Unhandled exception :: (Line: $($_.InvocationInfo.ScriptLineNumber) Line: $($_.InvocationInfo.Line) Error message: $($_.exception.message))"
    }

}


#Process steps
#1 - Get user input to get subscription and VM name
$VMInput = Get-Menu 
if ($VMInput -eq $null)
{
    Write-host "No VM found try again"
    $VMInput = Get-Menu
}

#2 - Get SSO credentials
$Credential = Get-AzureRsCredential 
#3 - make sure azure context is set
Write-host "If you are not authenticated to your Rackspace Azure account you will be prompted for credentials." -ForegroundColor Yellow
Write-host "Wait for script to get IP details from Azure and credentials from the password safe" -ForegroundColor Yellow
$Context = Get-AzureRsAuthentication
#4 - Get the VM details from Azure
$VMinfoFinal = Get-VMDetailsFromAzure
#5 - Get Password Safe token
$Token = Get-AzureRsPasswordSafeToken -Credential $Credential
#Retrieve the Password 
$CredOut = Get-PasswordSafeCreds
$VMinfoFinal
$CredOut | fl