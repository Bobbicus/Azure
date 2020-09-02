

```Bash
#Get the az credentials to AKS and update local kubeconfig
az aks get-credentials --resource-group <ResourceGroupName> --name <AKSName> --overwrite-existing
```
Once you have authenticated to the cluster you can then run kubctl commands

## Get pod details 

```Bash
#list pods 
kubectl get pods 

#list pods in a given namespace
kubectl get pods -n <namespace-name>

#Output the pod details including recent log entries, get the pod id from previous command
kubectl describe pod <pod-name> -n <namespace-name>
```


## Remote SSH into a pod

```Bash
# list the pod names and copy the name of the pod you want to manage
kubectl get pods -n <namespace-name>

#Update the command below with the pod name from the last command
kubectl exec -it <pod-name>  /bin/sh -n <namespace-name>
```

## Assigning permission to the AKS cluster Managed SPN account

There will be situations where the AKS agent account will need additional permissions in azure.  The first step is to the the identity that is being used by your AKS cluster.  Run the command below

```Bash
#Get the ID of the cluster identity
az aks show -g myResourceGroup -n myManagedCluster --query "identity"

#Assigning roles to the Managed identity
az role assignment create --role "Managed Identity Operator" --assignee <ID> --scope /subscriptions/<SubscriptionID>/resourcegroups/<ClusterResourceGroup>
az role assignment create --role "Virtual Machine Contributor" --assignee <ID> --scope /subscriptions/<SubscriptionID>/resourcegroups/<ClusterResourceGroup>

#List all role assignments for a managed identity
az role assignment list --all --assignee 123456-abcde-123456-abcde-123456-abcde
```