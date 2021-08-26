$customLocationGroup="ArcWebAppRG"
$customLocationName="arc-web-custom-location"
$appplan = "arcwebappplan"
$webapp = "arcwebapp-asifdemo"
$runtime = "node|12-lts"

$customLocationId=$(az customlocation show --resource-group $customLocationGroup `
    --name $customLocationName --query id `
    --output tsv)

#==========================    
#Create an App Service plan
#==========================
az appservice plan create -g $customLocationGroup -n $appplan `
    --custom-location $customLocationId `
    --per-site-scaling --is-linux --sku K1    

#Create an app
az webapp list-runtimes

<#======================================
Need to run below code using Azure CLI
======================================#>
az webapp create \
    --plan 'arcwebappplan' \
    --resource-group 'ArcWebAppRG' \
    --name 'arcwebapp-asifdemo' \
    --custom-location 'arc-web-custom-location' \
    --runtime 'NODE|12-lts'    

# Deploy Code
git clone https://github.com/Azure-Samples/nodejs-docs-hello-world
cd nodejs-docs-hello-world
zip -r package.zip .
$compress = @{
  Path = "C:\_dev\_github\Azure-AppService-on-Azure-ARC\_gitcode\nodejs-docs-hello-world"
  CompressionLevel = "Fastest"
  DestinationPath = "package.zip"
}
Compress-Archive @compress

az webapp deployment source config-zip --resource-group $customLocationGroup --name $webapp --src package.zip

az webapp create --plan $appplan --resource-group $customLocationGroup --name "arcwebapp-asif-container" --custom-location $customLocationId --deployment-container-image-name mcr.microsoft.com/appsvc/node:12-lts

az webapp create --plan $appplan --resource-group $customLocationGroup --name "arcwebapp-swagger-container" --custom-location $customLocationId --deployment-container-image-name khanasif1/k8_client_user:rc2.5


kubectl get pods --namespace appservice-ns --watch