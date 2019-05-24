#AKS deployment using Windows nodes and images stored in ACR

These demo scripts build a Azure Kubernetes Service (AKS) cluster and a Windows node pool. It then creates a deployment on the cluster using a Windows image stored in a private container registry hosted on Azure container registry (ACR).

-The file AKS-deployment-demo.ps1 contains all the commands you need to build the cluster and the service.
-The file deploy.yaml contains the configuration to start your container in the cluster.

###Pre-requisites
-Windows nodes on AKS is currently in preview, so you will need to register for the preview and make sure you have the relevent CLIs installed see details on this page https://docs.microsoft.com/en-us/azure/aks/windows-container-cli
-You will need to have created the Windows image and stored this in ACR.  You will need to update the yaml file as explained below.
-For more information on working with the Kubernetes dashboard https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard

###Deployment file

The file is in yaml format.  This particular deployment is using a private image stored in Azure container registry.  To access it you need to have created the SPN in Azure to access the image.  The code to do this is in the script file . . . .. . . 

I have sanitised the document but the format should be as per the line below.  I have highlighted the section you need to update below.

```
acr1.azurecr.io/image1:latest
```


```
      containers:
      - name: your-acr
        image: <your-acr>.azurecr.io/<your-image>:<imageversion>
      imagePullSecrets:
      - name: acs-secret1
```

If you want to use an image from a public container registry you can remove the image pull secrets values and use sopmething like the example below.  In which case you would not need to create the SPN account or the kubectl secret


```
 containers:
      - name: sample
        image: mcr.microsoft.com/dotnet/framework/samples:aspnetapp
```

###Additional inforamtion
As well as the links above, once you have the cluster running you can try managing it via the kubernetes portal or review the az aks commands available here https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest