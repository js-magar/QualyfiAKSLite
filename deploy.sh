# azure-devops-track-aks-exercise-jash
export MSYS_NO_PATHCONV=1

#ssh-keygen -m PEM -t rsa -b 4096 -f ./keys/keys
SSHKey=$(awk '{print $2}' ./keys/keys.pub)
UserName="jashusername"
Name="jash"
RGName="azure-devops-track-aks-exercise-$Name"
AcrName="aksacr$Name"
AksClusterName="akscluster$Name"
Location="uksouth"
KVName="kv-$Name-$Location"
BastionName="bas-$Name-$Location-001"
AppGatewayName="agw-$Name-$Location-001"
#RoleDefinitons
ID=$(az ad group list --display-name 'AKS EID Admin Group' --query "[].{id:id}" --output tsv)
AcrPullRoleDefiniton=$(az role definition list --name 'AcrPull' --query "[].{name:name}" --output tsv)
ReaderRoleDefiniton=$(az role definition list --name 'Reader' --query "[].{name:name}" --output tsv)
ContributorRoleDefiniton=$(az role definition list --name 'Contributor' --query "[].{name:name}" --output tsv)
NetworkContribnutorRoleDefiniton=$(az role definition list --name 'Network Contributor' --query "[].{name:name}" --output tsv)
KeyVaultAdminRoleDefiniton=$(az role definition list --name 'Key Vault Administrator' --query "[].{name:name}" --output tsv)
KeyVaultSecretsUserRoleDefinition=$(az role definition list --name 'Key Vault Secrets User' --query "[].{name:name}" --output tsv)
MonitoringReaderRoleDefinition=$(az role definition list --name 'Monitoring Reader' --query "[].{name:name}" --output tsv)
MonitoringDataReaderRoleDefinition=$(az role definition list --name 'Monitoring Data Reader' --query "[].{name:name}" --output tsv)
GrafanaAdminRoleDefinition=$(az role definition list --name 'Grafana Admin' --query "[].{name:name}" --output tsv)

az group create --name $RGName --location $Location
az deployment group create --mode Complete --no-prompt true --resource-group $RGName --template-file ./bicep/main.bicep \
 --parameters entraGroupID=$ID acrRoleDefName=$AcrPullRoleDefiniton readerRoleDefName=$ReaderRoleDefiniton \
 contributorRoleDefName=$ContributorRoleDefiniton netContributorRoleDefName=$NetworkContribnutorRoleDefiniton \
 keyVaultAdminRoleDefName=$KeyVaultAdminRoleDefiniton keyVaultUserRoleDefName=$KeyVaultSecretsUserRoleDefinition monitoringReaderRoleDefName=$MonitoringReaderRoleDefinition  \
 monitoringDataReaderRoleDefName=$MonitoringDataReaderRoleDefinition grafanaAdminRoleDefName=$GrafanaAdminRoleDefinition \
 keyVaultName=$KVName adminUsername=$UserName adminPasOrKey=$SSHKey aksClusterName=$AksClusterName \
 acrName=$AcrName bastionName=$BastionName appGatewayName=$AppGatewayName location=$Location name=$Name #> /dev/null 2>&1

#az aks install-cli
# Clone app
#docker compose -f azure-voting-app-redis/docker-compose.yaml up -d   
#docker images
#docker ps
#docker compose down

sleep 5 
az acr show -n $AcrName  
az acr list -o table 
az acr login --name $AcrName
echo "Building Front"
az acr build --registry $AcrName --image mcr.microsoft.com/azuredocs/azure-vote-front:v1 ./azure-voting-app-redis/azure-vote --no-logs --no-wait
echo "Building Back"
az acr build --registry $AcrName --image mcr.microsoft.com/oss/bitnami/redis ./azure-voting-app-redis/azure-vote --no-logs

echo "Building Completed"

VALUE=demovalue
SECRET=demosecret
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
CLIENT_ID=$(az aks show -g $RGName -n $AksClusterName --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv)

az aks get-credentials --resource-group $RGName --name $AksClusterName --overwrite-existing
az acr list --resource-group $RGName --query "[].{acrLoginServer:loginServer}" --output table
az keyvault secret set --vault-name $KVName --name $SECRET --value $VALUE

export secretProviderClassName='jashspc'
export clientId=$CLIENT_ID
export KVName=$KVName
export tenantId=$AZURE_TENANT_ID
export secretName=$SECRET
 
kubectl create namespace production
envsubst < yaml/azure-vote.yaml | kubectl apply -f - --namespace production
kubectl apply -f ./yaml/container-azm-ms-agentconfig.yaml
kubectl autoscale deployment azure-vote-front --namespace production --cpu-percent=50 --min=1 --max=10
kubectl autoscale deployment azure-vote-back --namespace production --cpu-percent=50 --min=1 --max=10
sleep 10 

kubectl get pods --namespace production
kubectl describe pods --namespace production

#./tests/test1.sh $RGName $AppGatewayName
#./tests/test3.sh $RGName $BastionName $UserName