param (
    [Parameter(Mandatory=$True)][Alias('l')][string]$AZLOCATION = "",
    [Parameter(Mandatory=$True)][Alias('g')][string]$AZRGNAME = "",
    [Parameter(Mandatory=$True)][Alias('n')][string]$AZAPPNAME = "",
    [Parameter(Mandatory=$True)][Alias('p')][string]$AZAPPPLAN = "",
    [Parameter(Mandatory=$True)][Alias('a')][string]$AZAPPID = "",
    [Parameter(Mandatory=$True)][Alias('k')][string]$AZAPPKEY = ""
        )

# The env vars in this script should be set by the Jenkinsfile
write-host "Deploying : ResourceGroup=$AZRGNAME, AppName=$AZAPPNAME, AppPlan=$AZAPPPLAN, Location=$AZLOCATION"

# create the RG if it doesn't exists
if ('false' -eq (az group exists -n $AZRGNAME)) {
    az group create -n $AZRGNAME -l "$AZLOCATION"
}

# create the AppService Plan if it doesn't exists
$VAR0=(az appservice plan show --name "$AZAPPPLAN" --resource-group "$AZRGNAME" --query "id" -o tsv)
if ( 0 -eq $VAR0.Length ) {
    write-host -ForegroundColor Yellow "create AppPlan=$AZAPPPLAN"
    az appservice plan create --name "$AZAPPPLAN" --resource-group "$AZRGNAME" -l "$AZLOCATION" --sku S1
}

# create the AppService if it doesn't exists
$VAR0=(az webapp show --name "$AZAPPNAME" --resource-group "$AZRGNAME" --query "id" -o tsv )
if ( 0 -eq $VAR0.Length ) {
    write-host -ForegroundColor Yellow "create AppService=$AZAPPNAME"
    az webapp create --name "$AZAPPNAME" --resource-group "$AZRGNAME" --plan "$AZAPPPLAN"
    az webapp config set --resource-group $AZRGNAME --name $AZAPPNAME `
                     --java-version "11" --java-container "Java" --java-container-version "SE"
    az webapp config appsettings set --resource-group $AZRGNAME --name $AZAPPNAME --settings "AZAPPID=$AZAPPID"    
    az webapp config appsettings set --resource-group $AZRGNAME --name $AZAPPNAME --settings "AZAPPKEY=$AZAPPKEY"                     
    az webapp config appsettings set --resource-group $AZRGNAME --name $AZAPPNAME --settings "AZAPPGROUPS=basilgroup,sybilgroup"                        
}

mkdir tmp
Copy-Item web.config .\tmp
Copy-Item ./target/*.jar ./tmp/java-rest-api.jar
Push-Location tmp
Compress-Archive -Path .\* -Update -DestinationPath .\java-rest-api.zip
Pop-Location

az webapp deployment source config-zip -g $AZRGNAME -n $AZAPPNAME --src .\tmp\java-rest-api.zip

Remove-Item -Recurse -Force .\tmp

# az webapp delete --name $AZAPPNAME --resource-group $AZRGNAME 
# az appservice plan delete --name "$AZAPPPLAN" --resource-group "$AZRGNAME" 
