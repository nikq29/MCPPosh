# Knowledge bases

A knowledge base is a named collection of documents that one MCP server provides to agents. Use separate knowledge
bases for separate audiences or topics, for example `Contoso` for internal IT documentation and `Product` for
customer-facing product documentation.

## Create

```powershell
New-McpKnowledgeBase -Name Contoso -Description 'Internal IT documentation of Contoso: runbooks, architecture and FAQ.'
```

- Names start with a letter or digit and contain only letters, digits, `.`, `_` and `-` (at most 64 characters).
- The description is sent to agents as MCP server instructions and is part of the tool descriptions. Describe what
  the documentation covers and when the agent should use it.
- The knowledge base is created below `$env:MCPPOSH_HOME/knowledgebases` (default `~/.mcpposh/knowledgebases`).
- `-Path` creates it in another folder, for example on a network share:

```powershell
New-McpKnowledgeBase -Name Shared -Path Z:\mcpposh\Shared
Add-McpDocument -KnowledgeBase Z:\mcpposh\Shared -Path .\docs -Recurse
```

The knowledge base `Default` is created automatically by `Add-McpDocument`, `Get-McpDocument`,
`Search-McpDocument`, `Start-McpServer` and `Get-McpClientConfig` when it does not exist. Other names must be created
with `New-McpKnowledgeBase` first.

## List and inspect

```powershell
Get-McpKnowledgeBase
Get-McpKnowledgeBase -Name 'Con*'
Get-McpKnowledgeBase -Name Contoso | Format-List
```

The output contains `Name`, `Description`, `Documents`, `Characters`, `Tags`, `Revision`, `Created`, `Updated` and
`Path`. The revision increases with every change; servers use the manifest to detect changes.

## Change the description

```powershell
Set-McpKnowledgeBase -Name Contoso -Description 'Runbooks and architecture of the Contoso platform. Use it for any question about Contoso.'
```

Running servers pick up the new description within a second.

## Remove

```powershell
Remove-McpKnowledgeBase -Name OldDocs
```

The knowledge base folder is deleted with all documents and logs. Knowledge bases that are served by a running local
HTTP server are not removed; stop the server first with `Stop-McpServer -KnowledgeBase OldDocs`.

## Back up and transfer

`Export-McpKnowledgeBase` writes a ZIP archive with `knowledgebase.json`, `manifest.json`, the documents and the
search index. Logs, the lock file and the publish state are not included.

```powershell
Export-McpKnowledgeBase -Name Contoso -DestinationPath .\contoso-kb.zip
Import-McpKnowledgeBase -Path .\contoso-kb.zip                       # restore under the original name
Import-McpKnowledgeBase -Path .\contoso-kb.zip -Name ContosoTest     # import as a copy
Import-McpKnowledgeBase -Path .\contoso-kb.zip -Name Contoso -Force  # replace an existing knowledge base
```

The import only extracts the expected files and rejects entries that would be written outside the target folder.

## Publish to Azure Files

A centrally hosted server (see [Azure](hosting-azure.md)) reads the knowledge base from an Azure Files share. Keep
maintaining the knowledge base locally and publish it:

```powershell
Install-PSResource -Name Az.Storage    # once
Connect-AzAccount
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName mcpposhab12cd -ShareName mcpposh -ResourceGroupName rg-mcpposh -Prune
```

| Parameter | Purpose |
| --- | --- |
| `-ResourceGroupName` | reads the storage account key with `Get-AzStorageAccountKey` (requires `Connect-AzAccount`) |
| `-StorageAccountKey` | uses a storage account key directly |
| `-SasToken` | uses a SAS token with read, write, create, list and delete permissions |
| `-Context` | uses an existing storage context from `New-AzStorageContext` |
| `-RemoteName` | name of the knowledge base on the share; must match `MCPPOSH_KNOWLEDGEBASE` of the container |
| `-Prune` | deletes documents on the share that no longer exist locally |
| `-Force` | uploads all files instead of only the changed ones |

How publishing works:

1. The local files are copied to a snapshot while the knowledge base is locked.
2. The folders `knowledgebases/<name>/documents` and `index` are created on the share when needed.
3. Files whose SHA-256 hash differs from the last publish are uploaded; the manifest is always uploaded last, so the
   server only reloads when all files are in place.
4. With `-Prune`, remote documents and index files that do not exist locally are deleted.
5. The hashes are stored in `.publish/` in the local knowledge base for the next run.

The result contains `KnowledgeBase`, `Destination`, `Uploaded`, `Skipped`, `Deleted` and `Revision`.

## Working directly on a share

Instead of publishing, you can mount the Azure Files share (SMB) or any network share and set `$env:MCPPOSH_HOME`
to it. All cmdlets then work directly on the central knowledge base. Keep in mind that the share must allow file
locking for concurrent writers.
