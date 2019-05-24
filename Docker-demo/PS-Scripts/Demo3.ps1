################################################
# Create a single node swarm and add a service  #
################################################

#Create a SWARM, the local IP of this host which will be a management node
docker swarm init  --advertise-addr 10.0.0.4:2377 --listen-addr 10.0.0.4:2377

#The above command outputs the command to join the swarm as a worker.  
#You can run the below to get the token for adding new worker or manager nodes
docker swarm join-token manager
docker swarm join-token worker

#Check the state of the SWARM
docker node ls
########
## V1 ##
########
#Create a service to run on this node, using the same IIS image PORT 8080
docker service create --name web-swarm-demo-v1 -p 8080:8080 --replicas 1 iis-demo-v1
########
## V1 ##
########
#Create a service to run on this node, using the same IIS image  PORT 8081
docker service create --name web-swarm-demo-v2 -p 8081:8080 --replicas 1 iis-demo-v2


#Check all services 
docker service ls

#Check that the service is running and on what node
docker service ps web-swarm-demo-v1

docker service ps web-swarm-demo-v2

#Get the IP of this node to check it locally. 
#Use IP and port on Docker 8080 for both

Docker service inspect web-swarm-demo-v1


Docker service inspect web-swarm-demo-v2