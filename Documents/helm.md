# Helm Commands 

## Windows Helm Install

* Download latest version of Helm
    https://helm.sh/docs/intro/install/
    https://github.com/helm/helm/releases
* Add Path to Environment variables
* Once you have Helm ready, you can add a chart repository. One popular starting location is the official Helm stable charts:
    helm repo add stable https://kubernetes-charts.storage.googleapis.com/


Helm / k8s troubleshooting

Create a namespace
```
kubectl create namespace new-namespace
```

As we install services into namespaces we need to reference this when browsing to the resources
```
helm ls -n kong  
```
## Delete Helm deployments
If you need to delete a service deployed with Helm use Helm to delete as well
```
helm delete app1 -n new-namespace
```

Dry Run

This will run and output what actions helm would take so you can inspect it. Use the --dry-run switch
```
#the . runs the command from the current directory use -f for another file location 
helm install --dry-run app1 . --set deployment.rds_passwords=1234abcde -n new-namespace 
```

You may want to pass variables at the command line like password for local deployments so they are not in the config files.  To do this use the --set command 
```
helm install --dry-run app1 . --set deployment.fb_passwords=1234abcde -n new-namespace 
```

Debug

To get more details you can also use the Debug switch 

helm install --debug --dry-run app1 . --set deployment.fb_passwords=1234abcde -n new-namespace 

Once you are ready to deploy it just remove the dry run switch 
```
helm install --debug --dry-run app1 . --set deployment.fb_passwords=1234abcde -n new-namespace 
```

When you have multiple environments you may have multiple value files to use this instead of the default values.yaml you must use the --values switch as below

```
helm install --debug --dry-run app1 . --values=dev-values.yaml --set deployment.fb_passwords=1234abcde -n new-namespace 
```

Upgrade

If you make changes to a helm chart or service you can apply the changes using helm upgrade

```
helm upgrade --debug --dry-run app1 . --values=dev-values.yaml --set deployment.fb_passwords=1234abcde -n new-namespace 
```

#dry run check uninstall
helm uninstall --debug app1 --dry-run . -n new-namespace 
#Uninstall helm deployment
helm uninstall --debug app1 . -n new-namespace 

tenancy/tenancy

helm list --all -n tenancy

#list all helm deployments
helm ls

#list applications in a particular namespace
helm ls -n new-namespace 

#list applications in all namespaces 
helm ls --all-namespaces
