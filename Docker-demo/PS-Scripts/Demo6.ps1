#Login to you azure account
az login

#set the azure subscription 
az account set --subscription a1e5691a-8c2d-4321-8fcb-4da22f11ecd0

#loginto Azure container registry
az acr login --name bobdock1

#pull down an image
docker pull bobdock1.azurecr.io/iisnew:v1