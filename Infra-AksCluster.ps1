#Login to Azure
az login


$aksClusterGroupName="ArcWebAppRG" # Name of resource group for the AKS cluster
$aksName="Arc-webapp-aks" # Name of the AKS cluster
$resourceLocation="eastus" 

#az aks delete --name $aksName --resource-group $aksClusterGroupName

az group create -g $aksClusterGroupName -l $resourceLocation
az aks create --resource-group $aksClusterGroupName --name $aksName --enable-aad --generate-ssh-keys
$infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)
az network public-ip create --resource-group $infra_rg --name MyPublicIP --sku STANDARD
$staticIp=$(az network public-ip show --resource-group $infra_rg --name MyPublicIP --output tsv --query ipAddress) 

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

#Save the id property of the App Service extension
$extensionId=$(az k8s-extension show `
    --cluster-type connectedClusters `
    --cluster-name $clusterName `
    --resource-group $groupName `
    --name $extensionName `
    --query id `
    --output tsv)
#Result: /subscriptions/9907fc36-386a-48e6-9b00-0470d5f7cab7/resourceGroups/ArcWebAppRG/providers/Microsoft.Kubernetes/connectedClusters/ArcWebAppRG-cluster/providers/Microsoft.KubernetesConfiguration/extensions/appservice-ext

#Wait for the extension to fully install before proceeding. You can have your terminal session wait until this complete by running the following command

az resource wait --ids $extensionId --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview"

kubectl get pods -n $namespace