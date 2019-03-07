<#
    .SYNOPSIS
    Azure script  - set the environment variable for ARM_ACCESS_KEY.
       
    .DESCRIPTION
    User picks which enviroenment they are working on and the script will change the subscription and get teh primary account key for the relevant storage account and set environment variable for ARM_ACCESS_KEY.
    Prerequisites: Terraform storage account must exist
    Makes changes: Yes
    Changes Made:
        Set the local computer environment variable for ARM_ACCESS_KEY.


    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 4.0
    Version Table:
    Version :: Author             :: Live Date   :: 
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 28-Feb-2019 :: 
#>

$CurrentArmKey = Get-childitem ENV: | where {$_.name -eq "ARM_ACCESS_KEY"}
Write-host "Current Access key is set to:" -ForegroundColor Green
$CurrentArmKey
$UserInput = read-host "`nDo you want to change the ARM_ACCESS_KEY? (y or n)"
while("y","n" -notcontains $UserInput)
    {
	    $UserInput = Read-Host "Do you want to change the ARM_ACCESS_KEY?(y or n)"
    }

If ($UserInput -eq "y")
    {
        $env = @("prod","nonprod","test","uat","ps","stg","dev")
        $EnvInput = $env | Out-GridView -OutputMode Single
        if ($EnvInput -eq "prod")
        {
            
            Set-AzureRmContext -Subscription "Microsoft Azure Enterprise Production"
            $storAccount = "terraformukw"+$EnvInput
            az account set -s "Microsoft Azure Enterprise Production"

        }
        elseif ($EnvInput -eq "nonprod")
        {
            
            Set-AzureRmContext -Subscription "Microsoft Azure Enterprise Non-Production"
            $storAccount = "terraformukw"+$EnvInput
            az account set -s "Microsoft Azure Enterprise Non-Production"
        }
        else
        {
            
            Set-AzureRmContext -Subscription "Microsoft Azure Enterprise Non-Production"
            $storAccount = "terraformuks"+$EnvInput
            az account set -s "Microsoft Azure Enterprise Non-Production"
        }
        $ActiveSub  = Get-AzureRMContext | select 
        Write-Host Current subsctiption is $ActiveSub.name -ForegroundColor Green
        Write-Host "`nRetrieving key for storage account $storAccount" -ForegroundColor Green
        $TerraformStore = Get-AzureRmStorageAccount | Where-object {$_.StorageAccountName -eq "$storAccount"}
        $TFStorKey = Get-AzureRmStorageAccountKey -ResourceGroupName $TerraformStore.ResourceGroupName -Name $TerraformStore.StorageAccountName

        $TFPrimaryKey = $TFStorKey[0].Value
        Write-Host "`nSetting Environment value for ARM_ACCESS_KEY $TFPrimaryKey" -ForegroundColor Green
        [Environment]::SetEnvironmentVariable("ARM_ACCESS_KEY",$TFPrimaryKey,"User")
        
        #Comment out line above and uncomment line below to use a temporary env var.  This will only be valide for the session but does not need you to stop/start the Powershell session.
        #$env:ARM_ACCESS_KEY = $TFPrimaryKey
        
        #Comment out below if use temp var.
        Write-Host "`n***You need to close and re-open Powershell or VSCode to use the new access key, run 'Get-childitem ENV: to confirm you have the latest key***" -ForegroundColor Yellow
    }
elseif ($UserInput -eq "n")
    {
        Write-Host "`nNot changing the ARM_ACCESS_KEY"
    }
