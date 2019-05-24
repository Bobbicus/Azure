##################
# Docker basics  #
##################

#Check for exising containers, the -a switch also shows in active containers
docker ps -a

#Check for existing images
docker images

#Pull down the Windows nano server image
docker pull mcr.microsoft.com/windows/nanoserver:1809
