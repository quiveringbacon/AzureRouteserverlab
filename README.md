# Azure Routeserver lab with CSR1000v

This creates an onprem vnet with Cisco CSR1000v connected to a hub vnet CSR1000v that is peered with a route server, and a spoke vnet peered to the hub. VM's are created in all 3 vnets. You'll be prompted for the resource group name, location where you want the resources created, your public ip, and username and password to use for the VM's and NVA. NSG's are placed on the default subnets of each vnet allowing RDP access from your public ip. This also creates a logic app that will delete the resource group in 24hrs. The topology will look something like this:

![image](https://github.com/quiveringbacon/AzureRouteserverlab/assets/128983862/fca4e280-acbc-44b7-88b1-a15849f363ea)

You can run Terraform right from the Azure cloud shell by cloning this git repository with "git clone https://github.com/quiveringbacon/AzureRouteserverlab.git ./terraform". Then, "cd terraform" then, "terraform init" and finally "terraform apply -auto-approve" to deploy.
