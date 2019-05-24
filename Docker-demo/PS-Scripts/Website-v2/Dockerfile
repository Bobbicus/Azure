# Sample Dockerfile

# Indicates that the windowsservercore image will be used as the base image.
FROM mcr.microsoft.com/windows/servercore:1809

# Metadata indicating an image maintainer.
LABEL Description="IISv2" Vendor="Microsoft"

# Uses PowerShell  to install the IIS role.
RUN powershell -Command Add-WindowsFeature Web-Server
RUN powershell -Command Install-WindowsFeature NET-Framework-45-ASPNET
RUN powershell -Command Install-WindowsFeature Web-Asp-Net45

COPY \demosite C:\\web-app

RUN powershell New-WebAppPool -name 'myapppool'
RUN powershell New-Website -Name 'my-app' -Port 8080 -PhysicalPath 'c:\web-app' -ApplicationPool 'myapppool'

# Sets a command or process that will run each time a container is run from the new image.
CMD [ "ping", "localhost", "-t" ]