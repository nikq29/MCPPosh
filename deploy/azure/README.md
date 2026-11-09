# MCPPosh on Azure Container Apps

This folder contains the deployment for hosting MCPPosh centrally in Azure:

| File | Purpose |
| --- | --- |
| [`main.bicep`](main.bicep) | Log Analytics, storage account with the Azure Files share `mcpposh`, Container Apps environment and the MCPPosh Container App |
| [`deploy.ps1`](deploy.ps1) | deployment with Az PowerShell, optionally publishing the local knowledge base |

```powershell
Connect-AzAccount
./deploy/azure/deploy.ps1 -ResourceGroupName rg-mcpposh -Image ghcr.io/nikq29/mcpposh:latest -KnowledgeBase Contoso -Publish
```

The complete guide with all parameters, publishing, client configuration and operations is in
[docs/hosting-azure.md](../../docs/hosting-azure.md).
