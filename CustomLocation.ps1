#========================
#Create a custom location
#========================
$customLocationName="arc-web-custom-location" # Name of the custom location

$connectedClusterId=$(az connectedk8s show --resource-group $groupName --name $clusterName --query id --output tsv)

#Create the custom location

az customlocation create `
    --resource-group $groupName `
    --name $customLocationName `
    --host-resource-id $connectedClusterId `
    --namespace $namespace `
    --cluster-extension-ids $extensionId

# Validate custom location creation
az customlocation show --resource-group $groupName --name $customLocationName    

#Save the custom location ID

$customLocationId=$(az customlocation show --resource-group $groupName `
    --name $customLocationName --query id  --output tsv)

#=============================================    
#Create the App Service Kubernetes environment
#=============================================
az appservice kube create `
    --resource-group $groupName `
    --name $kubeEnvironmentName `
    --custom-location $customLocationId `
    --static-ip $staticIp

#Validate that the App Service Kubernetes environment
az appservice kube show --resource-group $groupName --name $kubeEnvironmentName