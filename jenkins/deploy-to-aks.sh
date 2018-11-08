#/bin/bash

CONTAINERNAME=$1
CONTAINERVERSION=$2
# The env vars in this script should be set by the Jenkinsfile

echo "Deploying : ResourceGroup=$AZRGNAME, ACR=$AZACRNAME, AKS=$AZAKSNAME, Location=$AZLOCATION"

# login to ACR/AKS
az acr login --name $AZACRNAME
az aks get-credentials --resource-group $AZRGNAME --name $AZAKSNAME

# get the server name of the ACR
ACRLOGINSERVER=$(az acr show --resource-group $AZRGNAME --name $AZACRNAME --query "loginServer" --output tsv)

# tag the container for ACR and push it
docker tag $CONTAINERNAME:$CONTAINERVERSION $ACRLOGINSERVER/$CONTAINERNAME:$CONTAINERVERSION
docker tag $CONTAINERNAME:$CONTAINERVERSION $ACRLOGINSERVER/$CONTAINERNAME:latest
docker push $ACRLOGINSERVER/$CONTAINERNAME:latest

# modify the deployment yaml
cp ./deploy-aks-generic.yaml ./deploy-aks.yaml
sed -i -e "s/xxx-CONTAINERNAME-xxx/$CONTAINERNAME/g" ./deploy-aks.yaml
sed -i -e "s/xxx-replace-me-ACRLOGINSERVER-xxx/$ACRLOGINSERVER/g" ./deploy-aks.yaml

# deploy
kubectl apply -f ./deploy-aks.yaml

rm ./deploy-aks.yaml

# get the http dns name for the AKS cluster and modify the ingest yaml file
cp ./ingress-aks-generic.yaml ./ingress-aks.yaml
DNSZONE=$(az aks show --resource-group $AZRGNAME --name $AZAKSNAME --query "addonProfiles.httpapplicationrouting.config.httpapplicationroutingzonename" -o table | tail -n1)
sed -i -e "s/xxx-CONTAINERNAME-xxx/$CONTAINERNAME/g" ./ingress-aks.yaml
sed -i -e "s/xxx-replace-me-DNSZONE-xxx/$DNSZONE/g" ./ingress-aks.yaml

# deploy
kubectl apply -f ./ingress-aks.yaml

rm ./ingress-aks.yaml

# az aks browse --resource-group $AZRGNAME --name $AZAKSNAME