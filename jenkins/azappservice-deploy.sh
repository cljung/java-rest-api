#/bin/bash

# The env vars in this script should be set by the Jenkinsfile

echo "Deploying : ResourceGroup=$AZRGNAME, AppName=$AZAPPNAME, AppPlan=$AZAPPPLAN, Location=$AZLOCATION"

# create the RG if it doesn't exists
VAR0=$(az group show -n $AZRGNAME --query id -o tsv)
if [ -z "$VAR0" ]; then
    az group create -n $AZRGNAME -l "$AZLOCATION"
fi

# create the AppService Plan if it doesn't exists
VAR0=$(az appservice plan show --name "$AZAPPPLAN" --resource-group "$AZRGNAME" --query "appServicePlanName" -o tsv)
if [ -z "$VAR0" ]; then
    echo "create AppPlan=$AZAPPPLAN"
    az appservice plan create --name "$AZAPPPLAN" --resource-group "$AZRGNAME" -l "$AZLOCATION" --sku S1
fi

# create the AppService if it doesn't exists
VAR0=$(az webapp show --name "$AZAPPNAME" --resource-group "$AZRGNAME" --query "defaultHostName" -o tsv )
if [ -z "$VAR0" ]; then
    echo "create AppService=$AZAPPNAME"
    az webapp create --name "$AZAPPNAME" --resource-group "$AZRGNAME" --plan "$AZAPPPLAN"
    if grep --quiet "<packaging>jar</packaging>" ./pom.xml; then 
        az webapp config set --resource-group $AZRGNAME --name $AZAPPNAME \
                     --java-version "1.8" --java-container "Java" --java-container-version "SE"
    else # packaging war assumed
        az webapp config set --resource-group $AZRGNAME --name $AZAPPNAME \
                     --java-version "1.8" --java-container "Tomcat" --java-container-version "8.0"
    fi
    az webapp config appsettings set --resource-group $AZRGNAME --name $AZAPPNAME --settings "AZAPPID=$AZAPPID AZAPPKEY=$AZAPPKEY AZAPPGROUPS=basilgroup,sybilgroup"    
fi

mkdir webapps
cp ./target/*.jar ./webapps/java-rest-api.jar
if grep --quiet "<packaging>jar</packaging>" ./pom.xml; then 
    cp web.config ./webapps
    pushd webapps
    zip ./java-rest-api.zip web.config java-rest-api.jar
    popd
else # packaging war assumed
    zip ./webapps/java-rest-api.zip java-rest-api.jar
fi

az webapp deployment source config-zip -g $AZRGNAME -n $AZAPPNAME --src ./webapps/java-rest-api.zip

rm -fdR ./webapps

exit 0
: '
# get ftp server, userid/password to use for deploy
FTPURL=$(az webapp deployment list-publishing-profiles -g $AZRGNAME -n $AZAPPNAME --query "[1].publishUrl" -o tsv)
FTPUID=$(az webapp deployment list-publishing-profiles -g $AZRGNAME -n $AZAPPNAME --query "[1].userName" -o tsv)
FTPPWD=$(az webapp deployment list-publishing-profiles -g $AZRGNAME -n $AZAPPNAME --query "[1].userPWD" -o tsv)

# parse ftp url into server name with lovely bash commands
FTPSERVER=$(echo $FTPURL | sed 's/ftp:\/\///' | cut -d '/' -f 1 | sed 's/"//')
len=$(echo $FTPSERVER | awk '{print length}')
len=$((len+7))
FTPDIR=$(echo $FTPURL | cut -c $len-99 | sed 's/"//')

# ftp the JAR and web.config
# echo "ftp deploy WAR --> $FTPSERVER $AZAPPNAME $FTPDIR/webapps"
echo "ftp deploy JAR --> $FTPSERVER $AZAPPNAME $FTPDIR"

#cp ./target/*.war ./target/java-rest-api.war
cp ./target/*.jar ./target/java-rest-api.jar

# upload files via ftp to Azure AppServices
ftp -p -n $FTPSERVER << EOF

user "$FTPUID" "$FTPPWD"
cd $FTPDIR/webapps
cd $FTPDIR
del web.config
put web.config
lcd ./target
binary
del java-rest-api.jar
put java-rest-api.jar
quit

EOF
'

# az webapp delete --name $AZAPPNAME --resource-group $AZRGNAME 
# az appservice plan delete --name "$AZAPPPLAN" --resource-group "$AZRGNAME" 
