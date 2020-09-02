Container commands
```Bash
#Login to ACR
az acr login --name reg-name
```

```Bash
#list images
docker images 
```

```Bash
#Create a docker build passing ssh key from local files - bash cmd
docker build -t %image-name%  . --build-arg SSH_PRIVATE_KEY="$(cat /mnt/c/Users/username/.ssh/id_rsa)" 
```

```Bash
#Tag image ready to be used in ACR
docker tag %image-name% %container-reg-name%.azurecr.io/%image-name%
```

```Bash
#Push image to ACR
docker push %container-reg-name%.io/%image-name%
```

```Bash
#List images local docker repo 
docker image rm 53d4f5597077
```

```Bash
#Remove images get image id from list 
docker image rm 12345abc6789
```