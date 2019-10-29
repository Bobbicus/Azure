configuration webserver
{
    Import-DSCResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    $DestinationPath = 'c:\dogweb'
    $DestinationFile = '\demo-site.zip'
    $DestinationFilePath = $DestinationPath+$DestinationFile
    $WebsiteName = "DoGWeb"
   $StorageURI = "https://webststore.blob.core.windows.net/web-storage/demo-site.zip?s%SAS_TOKEN%
     node "localhost"
    {
        WindowsFeature IIS {
        Ensure = "Present"
        Name = "Web-Server"
        }
        WindowsFeature ASPNET {
        Ensure = "Present"
        Name = "NET-Framework-45-ASPNET"
        }
        WindowsFeature ASP {
        Ensure = "Present"
        Name = "Web-Asp-Net45"
        }
        File Directory
        {
            Ensure = "Present" # Ensure the directory is Present on the target node.
            Type = "Directory" # The default is File.
            DestinationPath = $DestinationPath
        }
        xRemoteFile SQLServerMangementPackage {  
            Uri             =  $StorageURI
            DestinationPath = $DestinationFilePath
            DependsOn       = "[File]Directory"
            MatchSource     = $false
        }
        Archive ArchiveExample
        {
            Ensure = "Present"
            Path = $DestinationFilePath 
            Destination = $DestinationPath 

        }
        Firewall AllowManagementPort
        {
                Name = "Allow Port 8080"
                DisplayName = "Allow Port 8080"
                Ensure = "Present"
                Protocol = "TCP"
                Enabled = "True"
                Direction = "InBound"
                LocalPort = 8080
                Profile = ('Domain', 'Private', 'Public')
        }
        xWebsite NewWebsite
        {
            Ensure          = "Present"
            Name            = $WebSiteName
            State           = "Started"
            PhysicalPath    = $DestinationPath
            BindingInfo     = @(
                MSFT_xWebBindingInformation
                {
                    Protocol              = "HTTP"
                    Port                  = 8080
                }

            )

        }
    }
}
