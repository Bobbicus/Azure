##################################################################
# This script will apply and reboot automatically all windows updates 
# oustanding on a windows box acording to its settings, eg it will apply 
# only Important and critical if reconmmended is not selected.
# You must suply a Scope of VM, Subscription or Resource Group.
# If you use scope = a VM you need to supply subscription name, Reseource group and VM name
# If you use scope = Subscription you only need to supply the subscription as the others are ignored
# If you use scope = resroucegroup you must supply Susbscription and ReseouceGroups, VM is ignored.
#
# Just run the PS1 file and interact with it using the menu system.

######### VERSION ##########

$version = 2.14

## Last change: Monitoring now only shows targeted VMs if you target VMs

############################



#Declare Paramaters and set them to either null or ""
[string]$resourcegroupname = ""
[string]$Global:subscriptionname = ""
[String]$Global:scope = ""
[string]$global:accouttype = ""
#$Global:vmname = $null
#$global:AzureCred = $null



$jobscriptblock1 = {     
    
    #login is required for each job as the job is clased as a new session
    Login-AzureRmAccount -Credential $args[2]
    Select-AzureRmSubscription -SubscriptionId $args[3]

    #this is the name of the extension used by this deployment
    $extensionName = "WindowsUPD-Patching"

    		#get the VM Status
            $myvm = Get-AzureRmVM -ResourceGroupName $args[0] -Name $args[1] -Status

			#check if the vmagent is running, otherwise we can't do much, other than a restart or ask the customer to troubleshoot if we can't get in to the box.
			if($myvm.VMAgent.Statuses.DisplayStatus -eq 'Ready')
			{     
				foreach($extension in $myvm.Extensions){
                    
                    #look for DSC extensions and if not the one we want to use remove it
					if ($extension.VirtualMachineExtensionType -like 'DSC')
					{
						Write-Host "   Removing current extension $($extension.Name) from $($myvm.Name). This might take a few minutes...`n" -ForegroundColor cyan
						Remove-AzureRmVMExtension -VMName $myvm.Name -ResourceGroupName $myvm.ResourceGroupName -Name $extension.Name -Force
					}

                    #if the extension is in an error status even if its the one we want to use, remove it
					elseif( ($extension.Name -eq $extensionName -and  $extension.statuses.DisplayStatus -ne 'Provisioning succeeded' ) )
					{
						Write-Host "Found an existing  DSC extension on $($myvm.Name) inn error status... removing it (if not done in 10 minutes, troubleshoot in portal)`n"
						Write-Verbose '   TODO: Make this a background task'
                
						Remove-AzureRmVMExtension -VMName $myvm.Name -ResourceGroupName $myvm.ResourceGroupName -Name $extension.Name -Force
                
					}

                    #use the existing extension 
					elseif(($extension.Name -eq $extensionName))
					{
						Write-verbose "   Found an existing DSC extension for $($extensionName).. will try to use this`n"
					}
				}
			}
            #if the VMagent is not ready let the use rknow we cant continue
			else
			{
				Write-Host "   VMAgent on VM $($_.Name) is not on status : $($myvm.VMAgent.Statuses.DisplayStatus).`n" -ForegroundColor Red
				exit
			}


#### This part calls for the Azure ResourceGroup deployment 
#### The template is currnelty hosted on My storage account.
    
    New-AzureRmResourceGroupDeployment -Mode Incremental -Name ('Windowsupdate' + '-' + ((Get-Date).ToUniversalTime()).ToString('yyyyMMdd-HHmmss')) `
    -ResourceGroupName $args[0] `
    -TemplateFile 'https://boysiedeploy.blob.core.windows.net/resources/extensions/windowsupdate.json' `
    -vmName $args[1] `
    -applyOSPatches "Yes" `
    -Force -Verbose }
     




#Function to apply all windows updates to the servers
function applyupdate { 

Try {

#Get all servers in the resouregroup which have a OS type of windows
$Servers= (Get-AzureRmVM -ResourceGroupName $resourcegroupname | where { $_.StorageProfile.OSDisk.OSType -eq "Windows" } | select -Property Name )


#For all servers found the resouregroup which have a OS type of windows
foreach ($server in $Servers) {

    write-host "Found windows server"$server.Name "in" $resourcegroupname "and applying windows Updates, Check the extension to see when its completed" -ForegroundColor Cyan

    ##Start the job using the scriptblock - 1 job per loop from the above foreach server in servers. Name the Job the Server name
    Start-Job -Name $server.Name -ScriptBlock {     
    
    #login is required for each job as the job is clased as a new session
    Login-AzureRmAccount -Credential $args[2]
    Select-AzureRmSubscription -SubscriptionId $args[3]

    #this is the name of the extension used by this deployment
    $extensionName = "WindowsUPD-Patching"

    		#get the VM Status
            $myvm = Get-AzureRmVM -ResourceGroupName $args[0] -Name $args[1] -Status
            #$myvm = Get-AzureRmVM -ResourceGroupName "WEU-RSG-MOR-ALL-PRD" -Name "MOR-VM-SQL01" -Status

			#check if the vmagent is running, otherwise we can't do much, other than a restart or ask the customer to troubleshoot if we can't get in to the box.
			if($myvm.VMAgent.Statuses.DisplayStatus -eq 'Ready')
			{     
				foreach($extension in $myvm.Extensions){
                    
                    #look for DSC extensions and if not the one we want to use remove it
					if ($extension.Type -eq 'Microsoft.Powershell.DSC')
					{
						Write-Host "   Removing current extension $($extension.Name) from $($myvm.Name). This might take a few minutes...`n" -ForegroundColor cyan
						Remove-AzureRmVMExtension -VMName $myvm.Name -ResourceGroupName $myvm.ResourceGroupName -Name $extension.Name -Force
					}

                    #if the extension is in an error status even if its the one we want to use, remove it
					elseif( ($extension.Name -eq $extensionName) -and ( $extension.statuses.DisplayStatus -ne 'Provisioning succeeded' ) )
					{
						Write-Host "Found an existing  DSC extension on $($myvm.Name) inn error status... removing it (if not done in 10 minutes, troubleshoot in portal)`n"
						Write-Verbose '   TODO: Make this a background task'
                
						Remove-AzureRmVMExtension -VMName $myvm.Name -ResourceGroupName $myvm.ResourceGroupName -Name $extension.Name -Force
                
					}

                    #use the existing extension 
					elseif(($extension.Name -eq $extensionName))
					{
						Write-verbose "   Found an existing DSC extension for $($extensionName).. will try to use this`n"
					}
				}
			}
            #if the VMagent is not ready let the use rknow we cant continue
			else
			{
				Write-Host "   VMAgent on VM $($_.Name) is not on status : $($myvm.VMAgent.Statuses.DisplayStatus).`n" -ForegroundColor Red
				exit
			}


#### This part calls for the Azure ResourceGroup deployment 
#### The template is currnelty hosted on My storage account.
    
    New-AzureRmResourceGroupDeployment -Mode Incremental -Name ('Windowsupdate' + '-' + ((Get-Date).ToUniversalTime()).ToString('yyyyMMdd-HHmmss')) `
    -ResourceGroupName $args[0] `
    -TemplateFile 'https://boysiedeploy.blob.core.windows.net/resources/extensions/windowsupdate.json' `
    -vmName $args[1] `
    -applyOSPatches "Yes" `
    -Force -Verbose } -ArgumentList $resourcegroupname, $server.name, $Global:AzureCred, $global:Subscription.id
    #Above is the argument list we need to use inside the script block for arg


    }

            }
    
Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }  

    }
    

#Currently unused, lett it there as may use for future releases.
function monitor
{ 
Try {

if ( ($vmname -ne $null) -and ($scope -eq "VM" ) ) { $monServers= $vmname }
else {$monServers=  (Get-AzureRmVM | where { $_.StorageProfile.OSDisk.OSType -eq "Windows" })} # | select -Property Name,status ) 


#$monServers.StatusCode # | gm
foreach ($monserver in $monservers) {

#$monserver = Get-AzureRmVM -name 'WIN-APP-01' -ResourceGroupName 'TESTVM-WIN-VMS-APP'
#Get-AzureRmVM -Name $monserver.name -ResourceGroupName $monserver.ResourceGroupName | ft

$statsoutput = Get-AzureRmVMExtension -ResourceGroupName $monserver.ResourceGroupName -VMName $monserver.Name -Name 'WindowsUPD-Patching' -ErrorAction SilentlyContinue | select -Property VMname,Name,ProvisioningState 

if ($statsoutput -eq $Null) {

Write-Output $($monserver.Name+"  WindowsUPD-Patching Extension Missing")


}
else {
$statsoutput | ft

}

}    

    }
Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }  
}



#Determine scope used and call deployments with necessary options and values set. 
function applytoscope {

Try {

#For Scope Suscriptions call the applyupdate funtion while looping through the resource groups. 
If ($scope -eq "Subscription") {

    $rsgs = Get-AzureRmResourceGroup | select -Property ResourceGroupName

    foreach ($rsg in $rsgs) {
    $resourcegroupname = $rsg.ResourceGroupName
    applyupdate
    #get-job
    

    }
}
##For Scope Resourcegroup call the applyupdate funtion while looping through the resource groups. (multipule groups supported)
elseIf ($scope -eq "Resourcegroup") {
    foreach ($rsg in $SelectRSGs) {
    $resourcegroupname = $rsg.name
    applyupdate
    #get-job
    }
}
#
# Single VM 
#Here we take the VMs selected and run the resource group deploymnet without using a job for each.
elseIf ($scope -eq "VM") {



        #check if the vm has been provided if its empty then throw it back with the msg 
        if ($vmname.Name -eq "") { Write-Host "You have not supplied a VM name but you have Scope set as VM, please retry supplying a VM name" 
                               return}
        
        #Becasue now there can be more than 1 VM we need to do a for each vm do the following etc
        foreach ($vm in $vmname) {


        #Start-Process -FilePath PowerShell -ArgumentList "-NoExit & {$vmscript}",$vmnames,$vmrsg,$AzureCred,$privatedeviceID

           
           Start-Job -Name $vm.Name -ScriptBlock {     
    
                #login is required for each job as the job is classed as a new session
                Login-AzureRmAccount -Credential $args[2]
                Select-AzureRmSubscription -SubscriptionId $args[3]

                #this is the name of the extension used by this deployment
                $extensionName = "WindowsUPD-Patching"

    		    #get the VM Status
                $myvm = Get-AzureRmVM -ResourceGroupName $args[0] -Name $args[1] -Status

			    #check if the vmagent is running, otherwise we can't do much, other than a restart or ask the customer to troubleshoot if we can't get in to the box.
			    if($myvm.VMAgent.Statuses.DisplayStatus -eq 'Ready')
			        {     
				        foreach($extension in $myvm.Extensions){
                    
                            #look for DSC extensions and if not the one we want to use remove it
					        if ($extension.Type -eq 'Microsoft.Powershell.DSC') # -and $extension.Name -ne $extensionName
					        {
						        Write-Host "   Removing current extension $($extension.Name) from $($myvm.Name). This might take a few minutes...`n" -ForegroundColor cyan
						        Remove-AzureRmVMExtension -VMName $myvm.Name -ResourceGroupName $myvm.ResourceGroupName -Name $extension.Name -Force
					        }

                            #if the extension is in an error status even if its the one we want to use, remove it
					        elseif( ($extension.Name -eq $extensionName) -and ( $extension.statuses.DisplayStatus -ne 'Provisioning succeeded' ) )
					        {
						        Write-Host "Found an existing  DSC extension on $($myvm.Name) inn error status... removing it (if not done in 10 minutes, troubleshoot in portal)`n"
						        Write-Verbose '   TODO: Make this a background task'
                
						        Remove-AzureRmVMExtension -VMName $myvm.Name -ResourceGroupName $myvm.ResourceGroupName -Name $extension.Name -Force
                
					        }

                            #use the existing extension 
					        elseif(($extension.Name -eq $extensionName))
					        {
						        Write-verbose "   Found an existing DSC extension for $($extensionName).. will try to use this`n"
					        }
				        }
			        }
                    #if the VMagent is not ready let the use rknow we cant continue
			        else
			        {
				        Write-Host "   VMAgent on VM $($_.Name) is not on status : $($myvm.VMAgent.Statuses.DisplayStatus).`n" -ForegroundColor Red
				        exit
			        }


#### This part calls for the Azure ResourceGroup deployment 
#### The template is currnelty hosted on My storage account.
    
    New-AzureRmResourceGroupDeployment -Mode Incremental -Name ('WinUPD' + '-' + ((Get-Date).ToUniversalTime()).ToString('yyyyMMdd-HHmmss')) `
    -ResourceGroupName $args[0] `
    -TemplateFile 'https://boysiedeploy.blob.core.windows.net/resources/extensions/windowsupdate.json' `
    -vmName $args[1] `
    -applyOSPatches "Yes" `
    -Force -Verbose } -ArgumentList $vm.ResourceGroupName, $vm.name, $Global:AzureCred, $global:Subscription.id 
    
        
        } #end of loop for each VM

        }
}



    
Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }  

}


Function get-account
{
    Try {

        if ($accountype -eq "deviceID") { 

            $privatedeviceID = Read-host "Please provide the Device ID"

            Get-AzureCoreDevice -Device $privatedeviceID

            }

        else {
            #$Global:AzureCred = Get-Credential

            }
            Login-AzureRmAccount 
            pause
        }
    Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }  
}




function select-accounttypemenu
{
             param (
           [string]$Title = 'Azure Windows Update:'
     )

    Try {
        
        

     cls
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host " "
     Write-Host "             $Title Account selection Menu                                         "
     Write-Host " "
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host " "
     Write-Host " " 
     Write-Host "[D] Select the Azure Support device ID with Azure Credentials."
     Write-Host "[A] Select this to enter the account details manually with user and password."
     Write-Host "[R]  - Press 'R' to return to the main menu!"
     Write-Host ""
     Write-Host ""
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host " "
     Write-Host ""


        }
    Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }  

}


function selectaccount
{


    Try {
     do
{
     select-accounttypemenu
     $input = Read-Host "Please make a selection"
     switch ($input)
     {
             'D' {
                cls
                Write-Host "   Enter the Device ID..." -ForegroundColor Cyan
                $accountype = "deviceID"
                Get-account
           } 'A' {
                cls
                Write-Host "   Enter Creds..." -ForegroundColor Cyan
                $accountype = "manual"
                Get-account
           } 'R' {
                return
           }
     }
     
}
until ($input -eq 'r')


        }
    Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        } 
}



Function get-sub {

    Try {

            "Select ARM subscription"
            $Global:Subscription = Get-AzureRmSubscription | Out-GridView -Title 'ARM Subscriptions' -PassThru

            Select-AzureRmSubscription -SubscriptionId $Global:Subscription.id

            }
    Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }  
}


function Get-RSGs{

    Try
    {

	    $ErrorActionPreference = "stop"
        Write-Host "Grabbing Resource Group Details from Azure Subscription" -ForegroundColor Yellow
       	
        $RSGs = @()
        $SubsRSGs = @()
    
	    $RSGs += Find-AzureRmResourceGroup | Select-Object Name,Location
	    Write-Host "Gathered Resource Groups" -ForegroundColor Green
   
	    $SubsRSGs += $RSGs
        $Global:SelectRSGs = @()
        $Global:SelectedRSGs = @()


        $SelectRSGs += $SubsRSGs | Sort-Object Name,Location | Out-GridView -Title "Select one or more Resource Groups (hold down the CTRL key for multiple selections)" -OutputMode Multiple
	
        foreach($SelectRSG in $SelectRSGs){
           Write-host $SelectRSG.name
        }

        while ($SelectRSGs -eq $null) {
	    	Write-Host "You did not select any Resource Groups!" -ForegroundColor Red
		    $SelectRSGs += $SubsRSGs | Sort-Object Name,Location | Out-GridView -Title "Select one or more Resource Groups (hold down the CTRL key for multiple selections)" -OutputMode Multiple
	    }

        }
        Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }    
}


Function Get-Scope
{

        Try
        {
            $Global:scope = ""
            $scopes = @('VM','Subscription','Resourcegroup')
            $Global:scope += $scopes | Out-GridView -Title "Select one or more Resource Groups (hold down the CTRL key for multiple selections)" -OutputMode Single

        }
        Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }    

}


Function Get-VMname
{
        Try
        {

            $Global:vmname = Get-AzureRmVM | Out-GridView -Title 'Select 1 or more VMs' -PassThru
            
            
            
        }
        Catch
        {
                $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
                    Write-Output "Script failed to run"
                    Write-Output $ErrMsg 
        }     

}





Function displayhelp
{


     param (
           [string]$Title = 'Azure Windows Update:'
     )
     cls
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host ""
     Write-Host "             $Title Help Menu                                         "
     Write-Host ""
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host ""
     Write-Host " " 
     Write-Host "Option 1 will allow you to auth to the customers enviroment, This is required."
     Write-Host "Option 2 will allow you to select the Subscription to work with, This is required."
     Write-Host "Option 3 will allow you to select the Resource group, this is only required if scope is set to Resource Group or if Scope is set to VM." 
     Write-Host "Option 4 allows you to select a single VM as the target. this is only required if the Scope is set to VM" 
     Write-Host "Option 5 allows you to set the scope of windows update, optiosn will be Subscription, Resource Group or a Single VM"
     Write-Host "[U]  - This will hit the big red button and call windows update on all the VMs found in the scope provided."
     Write-Host "[Q]  - Press 'Q' to quit. you know the score!"
     Write-Host ""
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host ""
     Write-Host "An example would be to use Option 1 to auth then Option 2 to set the subscription then option 5"
     Write-Host "to select Subscription as the scope of what to apply windows update to."
     Write-Host "Then hit U to apply windows update to ALL Windows VMs found in that Subscription."
     Write-Host ""
     Write-Host "WARNING: The VMs will auto reboot possibly many times unitll all Windows updates are installed"  -ForegroundColor Red
     Write-Host ""

     

}


Function Show-Menu
{

     param (
           [string]$Title = 'Azure Windows Update:'
     )
     cls
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host "             $Title Main Menu                                         "
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host " " 
     Write-Host "[1]  - Select the Account and Auth to work with." 
     #if the account is already selected display it
     if ($AzureCred -ne $null) { write-host "Complete: Using" $AzureCred.username -ForegroundColor Cyan }
     Write-Host "[2]  - Select the Subscription to work with."
     #if the sbscription is already selected display it.
     if ($Subscription -ne $null) { write-host "Complete: Using" $Subscription.name $Subscription.id -ForegroundColor Cyan }
     Write-Host "[3]  - Select the Resource group. (Multiple Groups Supported)" 
     
     if ($SelectRSGs.name -ne $null) { write-host "Complete: Using RSG" $SelectRSGs.name -ForegroundColor Cyan }
     Write-Host "[4]  - Select VM target."      
     if ($vmname -ne $null) { write-host "VM set to: " $vmname.Name "in Resource Group" $vmname.ResourceGroupName -ForegroundColor Cyan }
     Write-Host "[5]  - Select Scope, VM or Subscription or Resource Group."
     if ($scope -ne "") { write-host "Scope set to: " $scope -ForegroundColor Cyan }
     Write-Host ""
     Write-Host ""
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host ""
     Write-Host ""
     Write-Host "[U]  - Apply Windows update to the... $scope $($vmname.name)"
     Write-Host "[M]  - Monitor Extension status"
     Write-Host ""
     Write-Host ""
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host ""
     Write-Host ""
     Write-Host "[H]  - Display help."
     Write-Host "[Q]  - Press 'Q' to quit."
     Write-Host ""
     Write-Host "------------------------------------------------------------" -ForegroundColor Cyan



     
}



do
{
     Show-Menu
     $input = Read-Host "Please make a selection"
     switch ($input)
     {
             '1' {
                cls
                Write-Host "   Select account and enter cred..." -ForegroundColor Cyan
                selectaccount
           } '2' {
                cls
                Write-Host "   Select Subscription..." -ForegroundColor Cyan
                Get-sub
           } '3' {
                #cls
                Write-Host "   Select Resource Group...  " -ForegroundColor Cyan
                Get-RSGs
           } '4' {
                cls
                Write-Host "   Select VM...  " -ForegroundColor Cyan
                Get-VMname
           } '5' {
                cls
                Write-Host "   Select Scope...  " -ForegroundColor Cyan
                Get-Scope
           } 'U' {
                cls
                Write-Host "   Apply Windows update to all windows server in the selected scope $($Scope)... " -ForegroundColor Cyan
                applytoscope
           } 'M' {
                cls
                Write-Host "   Monitor Extension status...Creating means the patches are installing, if missing for long time target that vm and update " -ForegroundColor Cyan
                Monitor
           } 'H' {
                cls
                Write-Host "   Help... " -ForegroundColor Cyan
                displayhelp
           } 'q' {
                return
           }
     }
     pause
}
until ($input -eq 'q')
    
    

