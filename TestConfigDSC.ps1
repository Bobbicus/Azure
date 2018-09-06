configuration TestConfig
{
Import-DscResource -Module xWebAdministration 
Import-DscResource -Module  xPSDesiredStateConfiguration
    Node WebServer1
    {
        WindowsFeature IIS
        {
            Ensure               = 'Present'
            Name                 = 'Web-Server'
            IncludeAllSubFeature = $true

        }
        
        xRemoteFile WebContent
        {
            Uri = "https://rgautobotsdiag804.blob.core.windows.net/webdsccontent/Alien%20Auto%20Site.zip"
            DestinationPath = "C:\Inetpub\Websites\AlienAuto.zip"  
           
        }
        xWebsite NewSite 
        { 
            Ensure          = ‘Present’ 
            Name            = ‘NewSite’ 
            State           = ‘Stopped’ 
            PhysicalPath    = ‘C:\Inetpub\Websites\AlienAuto’ 
            DependsOn       = ‘[WindowsFeature]IIS’ 
        } 
 
   
        
    }

    Node NotWebServer
    {
        WindowsFeature IIS
        {
            Ensure               = 'Absent'
            Name                 = 'Web-Server'

        }
    }
}