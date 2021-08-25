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
Need to run below colland using Azure CLI
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
az webapp deployment source config-zip --resource-group myResourceGroup --name <app-name> --src package.zip
