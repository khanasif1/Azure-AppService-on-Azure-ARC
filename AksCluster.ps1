#Login to Azure
az login


$aksClusterGroupName="ArcWebAppRG" # Name of resource group for the AKS cluster
$aksName="Arc-webapp-aks" # Name of the AKS cluster
$resourceLocation="australiaeast" 

#az aks delete --name $aksName --resource-group $aksClusterGroupName

az group create -g $aksClusterGroupName -l $resourceLocation
az aks create --resource-group $aksClusterGroupName --name $aksName --enable-aad --generate-ssh-keys
$infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)  #MC_ArcWebAppRG_Arc-webapp-aks_australiaeast
az network public-ip create --resource-group $infra_rg --name MyPublicIP --sku STANDARD
$staticIp=$(az network public-ip show --resource-group $infra_rg --name MyPublicIP --output tsv --query ipAddress)  #13.75.219.16

# get Kubeconfig
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin

kubectl get ns
kubectl config view

#Connect the cluster you created to Azure Arc
$groupName=$aksClusterGroupName
$clusterName="${groupName}-cluster" # Name of the connected cluster resource
az connectedk8s connect --resource-group $groupName --name $clusterName

#Connect the cluster you created to Azure Arc
az connectedk8s show --resource-group $groupName --name $clusterName
<#
{
  "agentPublicKeyCertificate": "MIICCgKCAgEAuCiLdPDaS4oCuF0EZ11ZgG2BocGV9VdlZ11QHCi8KPxGoGovkAAf4F52sXLytSVnDsZGx4X1Lw2GZC57MpJyJIMjOBsIY8/On5J3pcjEkhPOSjpdCSHlfEpS2+bfF3RWpwSIUGEmQyZ3qI7Tu/bQmYD1DNAcWCsUougjk1RxCceGSvtYTWWF69jtBKttK0YgEXD7UbhQ8YGfluZ/DW2H+3gLxs8pfsnD7bo1QQuUN2+SBL1b8RUXXWjAlb1in7UwiYBkvGg6q4FqxPB/wFUxKdayYIOadU8WK6gOodBnKUl94gJPGl8tWzLPkl006gzcJEZTo81y4vhAPWzn8b7Qq4i6R9uptjBrcBXAfTDEH4+49XPEZmirAf+CXg7B+M+NL15IkCD53QuIv+OFiNooiebp1Avl1bvz6Ua+4dF0wk0Vzuydtx9xLzLDDpNdigtKI5PREKLMFwhtMShZ7o+W805qZL+9bn4mhHCV/cUEoiyX0yd43GAGxvforFAvo/L25lNOzuX4bh7UBIqRuJzKust5b8kFO1S7EJg80OF7V7fLEcqlX64/bo0yEwxF1oslAFgzVDHC1kiIO3AwqCvZGSlGyANyXS/fOqpDUHD4eoJMjCU5eOk1SDwkLO+UdO0owFAc2o6vmNoVJMnS3xlaM13iaJRaiYeBPprZa5eQ2DUCAwEAAQ==",
  "agentVersion": null,
  "connectivityStatus": "Connecting",
  "distribution": "aks",
  "id": "/subscriptions/9907fc36-386a-48e6-9b00-0470d5f7cab7/resourceGroups/ArcWebAppRG/providers/Microsoft.Kubernetes/connectedClusters/ArcWebAppRG-cluster",
  "identity": {
    "principalId": "1e959116-0898-46cc-86e0-b241151e1805",
    "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
    "type": "SystemAssigned"
  },
  "infrastructure": "azure",
  "kubernetesVersion": null,
  "lastConnectivityTime": null,
  "location": "australiaeast",
  "managedIdentityCertificateExpirationTime": null,
  "name": "ArcWebAppRG-cluster",
  "offering": null,
  "provisioningState": "Succeeded",
  "resourceGroup": "ArcWebAppRG",
  "systemData": {
    "createdAt": "2021-08-24T12:49:25.306530+00:00",
    "createdBy": "askha@microsoft.com",
    "createdByType": "User",
    "lastModifiedAt": "2021-08-24T12:49:34.732485+00:00",
    "lastModifiedBy": "64b12d6e-6549-484c-8cc6-6281839ba394",
    "lastModifiedByType": "Application"
  },
  "tags": {},
  "totalCoreCount": null,
  "totalNodeCount": null,
  "type": "microsoft.kubernetes/connectedclusters"
}
#>
#Validate the connection with the following command
az connectedk8s show --resource-group $groupName --name $clusterName

#Create a Log Analytics workspace

$workspaceName="$groupName-workspace"

az monitor log-analytics workspace create `
    --resource-group $groupName `
    --workspace-name $workspaceName

$logAnalyticsWorkspaceId=$(az monitor log-analytics workspace show `
    --resource-group $groupName `
    --workspace-name $workspaceName `
    --query customerId `
    --output tsv)
$logAnalyticsWorkspaceIdEnc=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($logAnalyticsWorkspaceId))# Needed for the next step
$logAnalyticsKey=$(az monitor log-analytics workspace get-shared-keys `
    --resource-group $groupName `
    --workspace-name $workspaceName `
    --query primarySharedKey `
    --output tsv)
$logAnalyticsKeyEnc=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($logAnalyticsKey))    

#Install the App Service extension
$extensionName="appservice-ext" # Name of the App Service extension
$namespace="appservice-ns" # Namespace in your cluster to install the extension and provision resources
$kubeEnvironmentName="ArcAppService" # Name of the App Service Kubernetes environment resource


az k8s-extension create `
    --resource-group $groupName `
    --name $extensionName `
    --cluster-type connectedClusters `
    --cluster-name $clusterName `
    --extension-type 'Microsoft.Web.Appservice' `
    --release-train stable `
    --auto-upgrade-minor-version true `
    --scope cluster `
    --release-namespace $namespace `
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" `
    --configuration-settings "appsNamespace=${namespace}" `
    --configuration-settings "clusterName=${kubeEnvironmentName}" `
    --configuration-settings "loadBalancerIp=${staticIp}" `
    --configuration-settings "keda.enabled=true" `
    --configuration-settings "buildService.storageClassName=default" `
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" `
    --configuration-settings "customConfigMap=${namespace}/kube-environment-config" `
    --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=${aksClusterGroupName}" `
    --configuration-settings "logProcessor.appLogs.destination=log-analytics" `
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${logAnalyticsWorkspaceIdEnc}" `
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${logAnalyticsKeyEnc}"