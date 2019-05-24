###################################################
# Build a customised image and run the container  #
###################################################

#build a new docker image using our docker file and the base Windows server core image
docker build -t iis-demo-v1  C:\Docker-Demo\Website

#Lets create a basic container on the local VM, this is calling the image name we just created.
#We are running this on port 8080 on both this host and docker.  This is how the docker file and IIS site is configured.
docker container run -d -p 8080:8080 iis-demo-v1

#lets check the status 
docker ps

#check it is running in IIS 
#  http://localhost:8080/ 

#Stop the container get container ID from docker ps command
docker stop <CONTAINER ID>