#Login to Azure
az login

$aksClusterGroupName="ArcWebAppRG" # Name of resource group for the AKS cluster
$aksName="Arc-webapp-aks" # Name of the AKS cluster
$resourceLocation="australiaeast" 

az group create -g $aksClusterGroupName -l $resourceLocation
az aks create --resource-group $aksClusterGroupName --name $aksName --enable-aad --generate-ssh-keys
$infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)  #MC_ArcWebAppRG_Arc-webapp-aks_australiaeast
az network public-ip create --resource-group $infra_rg --name MyPublicIP --sku STANDARD
$staticIp=$(az network public-ip show --resource-group $infra_rg --name MyPublicIP --output tsv --query ipAddress)  #13.75.219.16

# get Kubeconfig
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin

kubectl get ns
kubectl config view