# PSMcpKnowledgeBase on Azure Container Apps

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fnikq29%2FPSMcpKnowledgeBase%2Fmain%2Fdeploy%2Fazure%2Fazuredeploy.json)

This folder contains the deployment for hosting PSMcpKnowledgeBase centrally in Azure:

| File | Purpose |
| --- | --- |
| [`main.bicep`](main.bicep) | Log Analytics, storage account with the Azure Files share `psmcpkb`, Container Apps environment and the PSMcpKnowledgeBase Container App |
| [`azuredeploy.json`](azuredeploy.json) | `main.bicep` compiled to an ARM template for the Deploy to Azure button; regenerate it after changing `main.bicep` (see the comment at the top of `main.bicep`) |
| [`deploy.ps1`](deploy.ps1) | deployment with Az PowerShell, optionally publishing the local knowledge base |

```powershell
Connect-AzAccount
./deploy/azure/deploy.ps1 -ResourceGroupName rg-psmcpkb -Image ghcr.io/nikq29/psmcpkb:latest -KnowledgeBase Contoso -Publish
```

The complete guide with all parameters, publishing, client configuration and operations is in
[docs/hosting-azure.md](../../docs/hosting-azure.md).
