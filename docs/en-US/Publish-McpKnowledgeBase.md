---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Publish-McpKnowledgeBase.md
schema: 2.0.0
---

# Publish-McpKnowledgeBase

## SYNOPSIS
Publishes a local knowledge base to an Azure Files share used by a hosted MCPPosh server.

## SYNTAX

### ResourceGroup (Default)
```
Publish-McpKnowledgeBase [-Name] <String> -StorageAccountName <String> -ShareName <String>
 -ResourceGroupName <String> [-RemoteName <String>] [-Prune] [-Force]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Sas
```
Publish-McpKnowledgeBase [-Name] <String> -StorageAccountName <String> -ShareName <String> -SasToken <String>
 [-RemoteName <String>] [-Prune] [-Force] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### Key
```
Publish-McpKnowledgeBase [-Name] <String> -StorageAccountName <String> -ShareName <String>
 -StorageAccountKey <String> [-RemoteName <String>] [-Prune] [-Force]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Context
```
Publish-McpKnowledgeBase [-Name] <String> -ShareName <String> -Context <Object> [-RemoteName <String>] [-Prune]
 [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Maintain your documentation locally with Add-McpDocument and publish it to the file share
that the MCPPosh container (e.g.
in Azure Container Apps) mounts at /data.
The running
server picks up the new revision automatically.

Only files that changed since the last publish are uploaded.
The manifest is uploaded
last so the server always sees a consistent state.
-Prune removes documents from the
share that no longer exist locally.

Requires the Az.Storage module (Install-Module Az.Storage).

## EXAMPLES

### EXAMPLE 1
```
Connect-AzAccount
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName mcpposhab12cd -ShareName mcpposh -ResourceGroupName rg-mcpposh -Prune
```

Uploads the changed files of the knowledge base Contoso to the Azure Files share of a hosted server and deletes documents that were removed locally.
The storage key is read from the resource group.

### EXAMPLE 2
```
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName mcpposhab12cd -ShareName mcpposh -SasToken $sas -RemoteName Docs
```

Publishes with a SAS token into the knowledge base Docs on the share; the container must use MCPPOSH_KNOWLEDGEBASE=Docs.

## PARAMETERS

### -Name
Name or directory path of the local knowledge base to publish.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -StorageAccountName
Storage account that holds the share.

```yaml
Type: String
Parameter Sets: ResourceGroup, Sas, Key
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShareName
Azure Files share mounted by the container (the Bicep template creates 'mcpposh').

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -StorageAccountKey
Access key of the storage account that holds the Azure Files share.

```yaml
Type: String
Parameter Sets: Key
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SasToken
SAS token with read, write, create, list and delete permissions on the share.

```yaml
Type: String
Parameter Sets: Sas
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResourceGroupName
Resource group of the storage account; the key is read with Get-AzStorageAccountKey
(requires Connect-AzAccount).

```yaml
Type: String
Parameter Sets: ResourceGroup
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Context
An existing Azure Storage context (New-AzStorageContext).

```yaml
Type: Object
Parameter Sets: Context
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoteName
Knowledge base name on the share.
Defaults to the local name; must match
MCPPOSH_KNOWLEDGEBASE of the container.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Prune
Delete documents on the share that no longer exist locally.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Upload all files, not only the changed ones.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None. You cannot pipe objects to this cmdlet.
## OUTPUTS

### MCPPosh.PublishResult: KnowledgeBase, Destination, Uploaded, Skipped, Deleted and Revision.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Publish-McpKnowledgeBase.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Publish-McpKnowledgeBase.md)

[Export-McpKnowledgeBase]()

[Get-McpServer]()

[Test-McpServer]()

