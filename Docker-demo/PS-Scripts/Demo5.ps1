#########################################
##Add service to display container name #
#########################################

#Create a service to run on this node, using the same IIS image PORT 8080
docker service create --name whoami-demo -p 8082:80 --replicas 4 bobdock1.azurecr.io/whoami-dotnet:v1

#Check that the service is running and on what node
docker service ps whoami-demo

#check on each node for running containers
docker ps

#Browse to the site
PIP on each node and port 8082 - use IE and new tabs to show the change in container ID.

#On docker 2 we will leave the swarm and see the impact on nodes
docker swarm leave --force