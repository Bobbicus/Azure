############################################
# Add node to swarm and scale the service  #
############################################

#Run command below from manager node1
docker swarm join-token worker

#run the results of above on node 2
docker swarm join --token SWMTKN-1-2lnvk7f1jz4xy3qpq8diuqgthyy2c1lyurxrhibjuhquruvfvk-bhgkx3m33sd6xm5tpd41eskc0 10.0.0.4:2377 --advertise-addr 10.0.0.5:2377 --listen-addr 10.0.0.5:2377

#add this on the end --advertise-addr 10.0.0.5:2377 --listen-addr 10.0.0.5:2377

#############################################################################################################
#Browse to public IP od Docker 2 VM.  We can browse to the site even though it is not running any container #
#############################################################################################################


#Check SWARM now has 2 nodes
docker node ls

#check on each node for running containers
docker ps

#None on Docker2 browse public IP of both
#v1 public IP from Azure 8080
#v2 public IP from Azure 8081

#Scale the service up
docker service scale web-swarm-demo-v2=4

#Check that the service is running and on what node
docker service ps web-swarm-demo-v2


