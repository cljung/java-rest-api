#/bin/bash

CONTAINERNAME=$1
CONTAINERVERSION=$2
# The env vars in this script should be set by the Jenkinsfile

echo "Deploying : ResourceGroup=$AZRGNAME, ACR=$AZACRNAME, AKS=$AZAKSNAME, Location=$AZLOCATION"

# tag the container for ACR and push it
docker tag $CONTAINERNAME:$CONTAINERVERSION $ACRLOGINSERVER/$CONTAINERNAME:$CONTAINERVERSION
docker tag $CONTAINERNAME:$CONTAINERVERSION $ACRLOGINSERVER/$CONTAINERNAME:latest
docker push $AZACRLOGINSERVER/$CONTAINERNAME:latest

# get the server name of the ACR
ACRLOGINSERVER=$(az acr show --resource-group $AZRGNAME --name $AZACRNAME --query "loginServer" --output tsv)

# modify the deployment yaml
sed -i -e "s/xxx-CONTAINERNAME-xxx/$CONTAINERNAME/g" ./build/deploy-aks-generic.yaml
sed -i -e "s/xxx-replace-me-ACRLOGINSERVER-xxx/$AZACRLOGINSERVER/g" ./build/deploy-aks-generic.yaml

# deploy
kubectl apply -f ./build/deploy-aks-generic.yaml

# get the http dns name for the AKS cluster and modify the ingest yaml file
DNSZONE=$(az aks show --resource-group $AZRGNAME --name $AZAKSCLUSTERNAME --query addonProfiles.httpApplicationRouting.config.HTTPApplicationRoutingZoneName -o table | tail -n1)
sed -i -e "s/xxx-CONTAINERNAME-xxx/$CONTAINERNAME/g" ./build/ingress-aks-generic.yaml
sed -i -e "s/xxx-replace-me-DNSZONE-xxx/$DNSZONE/g" ./build/ingress-aks-generic.yaml

# deploy
kubectl apply -f ./build/ingress-aks-generic.yaml