# azure-devops-track-aks-exercise-jash
export MSYS_NO_PATHCONV=1

#Variables
SubId="e5cfa658-369f-4218-b58e-cece3814d3f1"
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

#RoleDefinitons
ID=$(az ad group list --display-name 'AKS EID Admin Group' --query "[].{id:id}" --output tsv)
AcrPullRoleDefiniton=$(az role definition list --name 'AcrPull' --query "[].{name:name}" --output tsv)
NetworkContribnutorRoleDefiniton=$(az role definition list --name 'Network Contributor' --query "[].{name:name}" --output tsv)
KeyVaultAdminRoleDefiniton=$(az role definition list --name 'Key Vault Administrator' --query "[].{name:name}" --output tsv)
KeyVaultSecretsUserRoleDefinition=$(az role definition list --name 'Key Vault Secrets User' --query "[].{name:name}" --output tsv)
MonitoringReaderRoleDefinition=$(az role definition list --name 'Monitoring Reader' --query "[].{name:name}" --output tsv)
MonitoringDataReaderRoleDefinition=$(az role definition list --name 'Monitoring Data Reader' --query "[].{name:name}" --output tsv)
GrafanaAdminRoleDefinition=$(az role definition list --name 'Grafana Admin' --query "[].{name:name}" --output tsv)

az account set --subscription $SubId
echo "Set Subscription"

#Checking if there are already keys stored locally
if [ -f ./keys/keys.pub ]; then
    echo "Key File Exists"
else
    echo "Creating Key File"
    ssh-keygen -m PEM -t rsa -b 4096 -f ./keys/keys.pub
fi
#Retrieving the public key
SSHKey=$(awk '{print $2}' ./keys/keys.pub)

#Creating the resource group
echo "Creating RG $RGName"
az group create --name $RGName --location $Location >nul
echo "RG Created"

echo ""
#Deploying bicep template
echo "Bicep Deployment Started"
az deployment group create --mode Complete --no-prompt true --resource-group $RGName --template-file ./bicep/main.bicep --parameters \
 entraGroupID=$ID \
 acrRoleDefName=$AcrPullRoleDefiniton \
 netContributorRoleDefName=$NetworkContribnutorRoleDefiniton \
 keyVaultAdminRoleDefName=$KeyVaultAdminRoleDefiniton \
 keyVaultUserRoleDefName=$KeyVaultSecretsUserRoleDefinition \
 monitoringReaderRoleDefName=$MonitoringReaderRoleDefinition  \
 monitoringDataReaderRoleDefName=$MonitoringDataReaderRoleDefinition \
 grafanaAdminRoleDefName=$GrafanaAdminRoleDefinition \
 keyVaultName=$KVName \
 adminUsername=$UserName \
 adminPasOrKey=$SSHKey \
 aksClusterName=$AksClusterName \
 acrName=$AcrName \
 bastionName=$BastionName \
 appGatewayName=$AppGatewayName \
 location=$Location \
 prefix=$Prefix >nul
#Checking if there were any errors
if [ $? -ne 0 ]; then
    echo "Bicep Deployment Has Error"
else
    echo "Bicep Deployment Completed"
fi

sleep 10 
echo "Building ACR"
#Logging into ACR
az acr login --name $AcrName
echo "Building Front"
#Importing image from Microsoft
az acr import --resource-group $RGName --name $AcrName --image azure-vote-front:v1 --source mcr.microsoft.com/azuredocs/azure-vote-front:v1 >nul
echo "Front Built"
echo "Building Back"
az acr import --resource-group $RGName --name $AcrName --image redis:6.0.8 --source mcr.microsoft.com/oss/bitnami/redis:6.0.8 >nul
echo "Back Built"
echo "ACR Build Completed"

#Variables
VALUE=demovalue
SECRET=demosecret
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
CLIENT_ID=$(az aks show -g $RGName -n $AksClusterName --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv)

#Obtaining Aks Credentials
echo "Getting AKS Credentials"
az aks get-credentials --resource-group $RGName --name $AksClusterName --overwrite-existing
echo "ACR Server Name"
az acr list --resource-group $RGName --query "[].{acrLoginServer:loginServer}" --output table 
echo "Creating Example Secret"
#Assigning KV Admin to group for this KV so we can create a secret
az role assignment create --assignee-object-id $ID --role "Key Vault Administrator" \
 --scope "/subscriptions/$SubId/resourceGroups/$RGName/providers/Microsoft.KeyVault/vaults/$KVName" >nul
 #Creating Secret
az keyvault secret set --vault-name $KVName --name $SECRET --value $VALUE >nul

#Assigning values to variables
export secretProviderClassName='jashspc'
export clientId=$CLIENT_ID
export KVName=$KVName
export tenantId=$AZURE_TENANT_ID
export secretName=$SECRET

echo "Creating Namespace"
#Creating Namespace
kubectl create namespace production >nul
echo ""
echo "Deploying Services + Ingresses"
#Substituting environment variables in the yaml/azure-vote.yaml file and then piping this ouput to be applied with the production namespace
envsubst < yaml/azure-vote.yaml | kubectl apply -f - --namespace production
#Applying yaml file for Subnet IP Usage
kubectl apply -f ./yaml/container-azm-ms-agentconfig.yaml 
echo ""
echo "Configuring Horizontal autoscaling"
kubectl autoscale deployment azure-vote-front --namespace production --cpu-percent=50 --min=1 --max=10
kubectl autoscale deployment azure-vote-back --namespace production --cpu-percent=50 --min=1 --max=10
sleep 10 
echo ""
echo "Completed"
