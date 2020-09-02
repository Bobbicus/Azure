<#
    .SYNOPSIS
    Script to get a list of the releases definition in an AzureDevOps project
       
    .DESCRIPTION
    Script to get a list of the releases definition in an AzureDevOps project, the defninition contains 

    keywords: AzureDevOps,Release,Definition
    Prerequisites: Must have Personal Access Token with permissions to list projects and releases
    Makes changes: No

    .EXAMPLE
    Full command: .\Get-ReleaseDefinitions.ps1
    Description: Get a list of the releases for a project within Azure DevOps
       
    .OUTPUTS
    Example Output:


    id        : 1
    name      : website.iac.arm.release
    revision  : 23
    createdOn : 2019-04-05T11:20:59.907Z
    createdBy : @{displayName=John Smith; 
                url=https://spsprodeus123.vssps.visualstudio.com/2341-234a-214-a8d4-1234331241234/_apis/Identities/12341-234a-214-a8d4-1234331241234; _links=; 
                id=9ee614a9-75fa-4215-a8d4-755de2b2f2d5; uniqueName=john.smith@yourdomain.com; 
                imageUrl=https://dev.azure.com/yourdomain/_apis/GraphProfile/MemberAvatars/aad.asdkjhfalkjsdfhlaksjfhdlaksjdhflkjsadhf; 
                descriptor=aad.;asdkjhfalkjsdfhlaksjfhdlaksjdhflkjsadhf}
    url       : https://vsrm.dev.azure.com/devopsguys/2341-234a-214-a8d4-1234331241234/_apis/Release/definitions/1

        
    .NOTES
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 14-Jun-2019 ::          :: Andrew Urwin :: Release
#>

$APIVersion = "5.1"
#region auth
Function New-AzDevOpsAuth
{
    Param
    (
        [Parameter(Mandatory=$true, HelpMessage="Specify a Personal Access Token")]$Token
    )

        # Base64-encodes the Personal Access Token (PAT) appropriately
        $script:base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{0}" -f $Token)))
}
#endregion

Function Get-AzDevOpsReleaseDefinitions
{
  Param
    (
        [Parameter(Mandatory=$true, HelpMessage="Specify an Azure Devops Organisation, example: 'devopsgroup'")]$Organisation,
        [Parameter(Mandatory=$true, HelpMessage="Specify a Project Name, example: 'DOG Test Project 1'")]$ProjectName
    )

     Try
    {
          

$json = @{}

$list1 = New-Object System.Collections.ArrayList
$list1 = @{"id"=607;"name"="null"}

$list = New-Object System.Collections.ArrayList
$list.Add(@{"alias"="test";"instanceReference"=$list1;})

$Body = @{

            definitionID = 6
            description = "testing"
            reason = "none"
        } 
$json = @{"artifacts"=$list;}
$json = $json + $body

$Body = $json | ConvertTo-Json -Depth 10

        $URI = ("https://vsrm.dev.azure.com/" + $Organisation + "/"+ $ProjectName + "/"  + "_apis/release/releases?api-version=" + $APIVersion);
        #Execute the invoke rest API.
        $Output = Invoke-RestMethod -Method Post -uri ($URI) -Headers @{
            Authorization = ("Basic {0}" -f $base64AuthInfo)  
           } -Body ($Body) -ContentType "application/json";
        $Output.value #| Select id,name,revision,createdon,createdby,url


    }
    Catch
    {
        #Information to be added to private comment in ticket when unknown error occurs
        $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
        Write-Output "Script failed to run"
        Write-Output $ErrMsg

    }
}

New-AzDevOpsAuth
Get-AzDevOpsReleaseDefinitions