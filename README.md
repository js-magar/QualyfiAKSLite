# QualyfiAKS
Welcome to my project.
In this project I have created a deployment file for a production ‘voting’ application on an AKS cluster with the following spec/requirements stated in this document.

To use this template please run the following command to connect to Azure with an authenticated account:
```
az login
```
Once connected please run the following code to deploy the template:
```
./deploy.sh
```
Spec/Requirements:
Using Azure CLI and Bicep deploy the following:

- [x] 1. Deploy a ‘free’ sku AKS cluster with a public control plane
- [x] 2. Deploy the voting application: https://github.com/Azure-Samples/azure-voting-app-redis
- [x] 3. Use a ‘basic’ sku ACR to store the application in your subscription and deploy from there
- [x] 4. Use Linux node pools using the Mariner OS (Microsoft Linux)
- [x] 5. Create two node pools, one for system and one for the application – use default sku for node pool vm’s which is ‘Standard_DS2_v2’
- [x] 6. Use ‘containerd’ for the container runtime
- [x] 7. Set the node pools to auto scale using the cluster autoscaler
- [x] 8. Set the pods to auto scale using the horizontal pod autoscaler
- [x] 9. Use an application namespace called ‘production’
- [x] 10. Use Azure CNI networking with dynamic allocation of IPs and enhanced subnet support
- [x] 11. Use AKS-managed Microsoft Entra integration, use the existing EID group ‘AKS EID Admin Group’ for Azure Kubernetes Service RBAC Cluster Admin access
- [x] 12. Use Azure role-based access control for Kubernetes Authorization
- [x] 13. Disable local user accounts 
- [x] 14. Use an Application Gateway for ingress traffic
- [x] 15. Use a NAT gateway for internet egress traffic
- [x] 16. Use a system assigned managed identity for the cluster
- [x] 17. Use the Azure Key Vault provider to secure Kubernetes secrets in AKS, create an example secret and attach it to the backend pods
- [x] 18. Use a ‘standard’ sku Bastion and public/private keys to SSH to the pods
- [x] 19. Enable IP subnet usage monitoring for the cluster
- [x] 20. Enable Container Insights for the cluster
- [x] 21. Enable Prometheus Monitor Metrics and Grafana for the cluster

Success Criteria:

- [x] 1. Connect to the application front end via the App Gateway public ip
- [x] 2. User node pool running without error with the front and back-end application
- [x] 3. SSH to a node via the Bastion and the SSH keys
```
./tests/test3.sh [ResourceGroupName] [BastionName] [UserName]
```
- [x] 4. From the node load a web page via the NAT Gateway
- [x] 5. Check cluster autoscaler logs for correct function of the cluster
- [x] 6. Confirm the Pod autoscaler is running  (bastion then vmss)
- [x] 7. Connect to a pod using kubectl bash command
```
./tests/test7.sh 
```
- [x] 8. Display the value of the example secret in the pod bash shell
```
./tests/test8.sh 
```
- [x] 9. Check Container Insights is running, via the portal
- [x] 10. Check Prometheus Monitor Metrics in Grafana instance
- [x] 11. Use Azure Loading Testing to load the AKS cluster resulting in autoscaling of the nodes and pods

