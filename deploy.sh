# azure-devops-track-aks-exercise-jash
export MSYS_NO_PATHCONV=1

SubId="e5cfa658-369f-4218-b58e-cece3814d3f1"
az account set --subscription $SubId
echo "Set Subscription"


if [ -f ./keys/keys.pub ]; then
    echo "Key File Exists"
else
    echo "Creating Key File"
    ssh-keygen -m PEM -t rsa -b 4096 -f ./keys/keys.pub
fi

#Variables
SSHKey=$(awk '{print $2}' ./keys/keys.pub)
UserName="jashusername"
Name="jash"
Prefix="aks-jm"
PrefixWO="aksjm"
RGName="azure-devops-track-aks-exercise-$Name"
AcrName="${PrefixWO}acr"
AksClusterName="${PrefixWO}cluster"
Location="uksouth"
KVName="$Prefix-kv-$Location"
BastionName="$Prefix-bas-$Location-001"
AppGatewayName="$Prefix-agw-$Location-001"
CostSaving=true
ProdDeployment=true

#RoleDefinitons
ID=$(az ad group list --display-name 'AKS EID Admin Group' --query "[].{id:id}" --output tsv)
AcrPullRoleDefiniton=$(az role definition list --name 'AcrPull' --query "[].{name:name}" --output tsv)
NetworkContribnutorRoleDefiniton=$(az role definition list --name 'Network Contributor' --query "[].{name:name}" --output tsv)
KeyVaultAdminRoleDefiniton=$(az role definition list --name 'Key Vault Administrator' --query "[].{name:name}" --output tsv)
KeyVaultSecretsUserRoleDefinition=$(az role definition list --name 'Key Vault Secrets User' --query "[].{name:name}" --output tsv)
MonitoringReaderRoleDefinition=$(az role definition list --name 'Monitoring Reader' --query "[].{name:name}" --output tsv)
MonitoringDataReaderRoleDefinition=$(az role definition list --name 'Monitoring Data Reader' --query "[].{name:name}" --output tsv)
GrafanaAdminRoleDefinition=$(az role definition list --name 'Grafana Admin' --query "[].{name:name}" --output tsv)

echo "Creating RG $RGName"
az group create --name $RGName --location $Location >nul
echo "RG Created"

echo ""

echo "Bicep Deployment Started"
az deployment group create --mode Complete --no-prompt true --resource-group $RGName --template-file ./bicep/main.bicep \
 --parameters entraGroupID=$ID acrRoleDefName=$AcrPullRoleDefiniton netContributorRoleDefName=$NetworkContribnutorRoleDefiniton \
 keyVaultAdminRoleDefName=$KeyVaultAdminRoleDefiniton keyVaultUserRoleDefName=$KeyVaultSecretsUserRoleDefinition monitoringReaderRoleDefName=$MonitoringReaderRoleDefinition  \
 monitoringDataReaderRoleDefName=$MonitoringDataReaderRoleDefinition grafanaAdminRoleDefName=$GrafanaAdminRoleDefinition \
 keyVaultName=$KVName adminUsername=$UserName adminPasOrKey=$SSHKey aksClusterName=$AksClusterName \
 acrName=$AcrName bastionName=$BastionName appGatewayName=$AppGatewayName location=$Location prefix=$Prefix >nul

if [ $? -ne 0 ]; then
    echo "Bicep Deployment Has Error"
else
    echo "Bicep Deployment Completed"
fi

sleep 10 
echo "Building ACR"
az acr login --name $AcrName
echo "Building Front"
az acr import --resource-group $RGName --name $AcrName --image azure-vote-front:v1 --source mcr.microsoft.com/azuredocs/azure-vote-front:v1 >nul
echo "Front Built"
echo "Building Back"
az acr import --resource-group $RGName --name $AcrName --image redis:6.0.8 --source mcr.microsoft.com/oss/bitnami/redis:6.0.8 >nul
echo "Back Built"
echo "ACR Build Completed"

VALUE=demovalue
SECRET=demosecret
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
CLIENT_ID=$(az aks show -g $RGName -n $AksClusterName --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv)
echo "Getting AKS Credentials"
az aks get-credentials --resource-group $RGName --name $AksClusterName --overwrite-existing
echo "ACR Server Name"
az acr list --resource-group $RGName --query "[].{acrLoginServer:loginServer}" --output table 
echo "Creating Example Secret"
az role assignment create --assignee-object-id $ID --role "Key Vault Administrator" \
 --scope "/subscriptions/$SubId/resourceGroups/$RGName/providers/Microsoft.KeyVault/vaults/$KVName" >nul
az keyvault secret set --vault-name $KVName --name $SECRET --value $VALUE >nul

export secretProviderClassName='jashspc'
export clientId=$CLIENT_ID
export KVName=$KVName
export tenantId=$AZURE_TENANT_ID
export secretName=$SECRET

echo "Creating Namespace"
kubectl create namespace production >nul
echo ""
echo "Deploying Services + Ingresses"
envsubst < yaml/azure-vote.yaml | kubectl apply -f - --namespace production
kubectl apply -f ./yaml/container-azm-ms-agentconfig.yaml 
echo ""
echo "Configuring Horizontal autoscaling"
kubectl autoscale deployment azure-vote-front --namespace production --cpu-percent=50 --min=1 --max=10
kubectl autoscale deployment azure-vote-back --namespace production --cpu-percent=50 --min=1 --max=10
sleep 10 
echo ""
echo "Completed"
