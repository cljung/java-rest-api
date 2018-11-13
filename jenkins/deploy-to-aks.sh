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
echo "ACRLOGINSERVER: $ACRLOGINSERVER"

# tag the container for ACR and push it
echo "docker tag/push"
docker tag $CONTAINERNAME:$CONTAINERVERSION $ACRLOGINSERVER/$CONTAINERNAME:$CONTAINERVERSION
docker tag $CONTAINERNAME:$CONTAINERVERSION $ACRLOGINSERVER/$CONTAINERNAME:latest
docker push $ACRLOGINSERVER/$CONTAINERNAME:latest

#DNSZONE=$(az aks show --resource-group $AZRGNAME --name $AZAKSNAME --query addonProfiles.httpApplicationRouting.config.HTTPApplicationRoutingZoneName -o table | tail -n1)
# when we set our own custome http application proxy name, AKS creates a new attribute all in lower case
DNSZONE=$(az aks show --resource-group $AZRGNAME --name $AZAKSNAME --query "addonProfiles.httpapplicationrouting.config.httpapplicationroutingzonename" -o tsv)
echo "DNSZONE: $DNSZONE"

# modify the deployment yaml
cp ./jenkins/deploy-aks-generic.yaml ./jenkins/deploy-aks.yaml
sed -i -e "s/xxx-CONTAINERNAME-xxx/$CONTAINERNAME/g" ./jenkins/deploy-aks.yaml
sed -i -e "s/xxx-replace-me-ACRLOGINSERVER-xxx/$ACRLOGINSERVER/g" ./jenkins/deploy-aks.yaml
sed -i -e "s/xxx-replace-me-DNSZONE-xxx/$DNSZONE/g" ./jenkins/deploy-aks.yaml

# deploy
echo "kubectl apply"
kubectl apply -f ./jenkins/deploy-aks.yaml

rm ./jenkins/deploy-aks.yaml

# az aks browse --resource-group $AZRGNAME --name $AZAKSNAME
