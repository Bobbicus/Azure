
###############################
# Create RG and set variables #
###############################

#Add variables and create the RG
$PASSWORD_WIN ="P@ssw0rd1234"
$RGName = "aks-rg01"
$AKSclusterName = "aks-cluster1"
$SubscriptionID = "0000000000000-0000000-0000-00000000000"
$ACRname = "registry1"
az group create --name $RGName --location northeurope


############################################
# Create the initial AKS cluster in Azure  #
############################################

#Create the initial kubernetes cluster, by default it is created with a Linux pool.
az aks create `
    --resource-group $RGName `
    --name $AKSclusterName `
    --node-count 1 `
    --os-type Windows `
    --kubernetes-version 1.14.0 `
    --generate-ssh-keys `
    --windows-admin-password $PASSWORD_WIN `
    --windows-admin-username "azureuser" `
    --enable-vmss `
    --enable-addons monitoring `
    --network-plugin azure `
    --no-wait

##############################
# Create a Windows node pool #
##############################

#Create a Windows node pool with one node named winnp1, nodepool name for windows is currently limited to 6 characters
az aks nodepool add `
    --resource-group $RGName `
    --cluster-name $AKSclusterName `
    --os-type Windows `
    --name winnp1 `
    --node-count 1 `
    --kubernetes-version 1.14.0 `
    --no-wait


###############################################
# Configuring the credentials for kuberenetes #
###############################################

#This command downloads credentials and configures the Kubernetes CLI to use them.
az aks get-credentials --resource-group $RGName --name $AKSclusterName --overwrite-existing
#You need --overwrite-existing when re-building a cluster with the same name otherwise you get an error as it has chached old creds

#List the nodepools in the cluster to check you have both
az aks nodepool list --resource-group $RGName --cluster-name $AKSclusterName 

#If you need to delete a node in the pool update the name of the pool below
#az aks nodepool delete  --cluster-name $AKSclusterName  --resource-group $RGName --name "linnp1"

#kubectl command to get the nodes and their current status
kubectl get nodes

#################################
# Access the kuberenetes portal #
#################################

#Set permissions to access the K8s portal
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard

#Browse to Kubernetes portal - RBAC needs to be configured to allow access https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard
az aks browse --resource-group $RGName --name $AKSclusterName

####################################################
# Create secret to access a private Azure registry #
####################################################
$Scope = "/subscriptions/$SubscriptionID/resourcegroups/docker/providers/Microsoft.ContainerRegistry/registries/$ACRName"
#Create an SPN with access to the Azure container registry
az ad sp create-for-rbac `
  --scopes $Scope `
  --role Contributor `
  --name aks-access-spn 

#From the output above add the SPN and username to vars, I just did this to save hard coding it
$SPN_Password = Read-Host "Enter your Azure SPN password"
$SPNUsername = Read-Host "Enter your Azure SPN Username"


#Create a Kube secret
kubectl create secret docker-registry acs-secret1 `
--docker-server="<your-docker-reg-server>" `
--docker-email="<your-email-address>" `
--docker-username=$SPNUsername `
--docker-password=$SPN_Password

#delete kubectl secrets if you need to delete secrets you can uncomment the command below.
#kubectl delete secret acs-secret1


#################################################
# Deploy your service using an image from ACR  #
#################################################


#Deploy a new service using a yaml file
kubectl apply -f C:\aks-deployments\deploy-2.yaml --validate=false


#####################################
# Checking your service is running  #
#####################################

#view the service and get the public IP, you need the name from the yaml file if you changed it.  
#You can then browse to your new site using the public IP
kubectl get service akstest1 --watch

#To cleanup after the testing the easiest way =is to delete the resource group
#az group delete --name $RGName --yes --no-wait