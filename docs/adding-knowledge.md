# Adding knowledge

`Add-McpDocument` imports files, folders, web pages and text into a knowledge base. Everything is converted to
Markdown when it is added, so the server only works with Markdown.

## Files and folders

```powershell
Add-McpDocument -KnowledgeBase Contoso -Path .\runbooks\vpn.md
Add-McpDocument -KnowledgeBase Contoso -Path .\docs -Recurse
Add-McpDocument -KnowledgeBase Contoso -Path .\docs -Recurse -Include *.md, *.docx -Exclude *draft* -Tags handbook
Get-ChildItem \\server\wiki -Filter *.html -Recurse | Add-McpDocument -KnowledgeBase Contoso
```

- `-Path` accepts files, folders and wildcards. Without `-Recurse` only the files directly in a folder are imported.
- `-Include` and `-Exclude` filter by file name with wildcards.
- Files in `.git`, `.svn`, `.hg`, `node_modules` and `.mcpposh` folders are skipped.
- `-Title` sets the title of all imported files; by default the title comes from the document itself.
- `-Tags` adds tags. When you import a file again without `-Tags`, its existing tags are kept.
- `-Format` forces a converter instead of detecting it from the extension.
- Errors for single files are reported as non-terminating errors; the other files are still imported.

## Web pages and online documents

```powershell
Add-McpDocument -KnowledgeBase Contoso -Url https://learn.microsoft.com/powershell/scripting/overview -Tags powershell
```

The URL is downloaded (at most five redirects, user agent `MCPPosh (PowerShell MCP documentation server)`) and
converted based on the `Content-Type` header:

| Content type | Converter |
| --- | --- |
| `text/html`, `application/xhtml+xml` | Html (relative links are resolved against the URL) |
| `text/markdown` | Markdown |
| `application/pdf` | Pdf |
| `...wordprocessingml...` | Docx |
| `text/csv` | Csv |
| `application/json`, `*+json` | Json |
| `application/yaml`, `text/yaml` | Yaml |
| `application/xml`, `text/xml`, `*+xml` | Xml |
| other | detected from the file extension in the URL, otherwise Text |

Only `http` and `https` URLs are accepted.

## Text and notes

```powershell
Add-McpDocument -KnowledgeBase Contoso -Title 'VPN error 809' -Content 'Check the firewall rule VPN-IKE.' -Tags vpn
Add-McpDocument -KnowledgeBase Contoso -Title 'Release notes' -Content (Get-Content .\notes.html -Raw) -Format Html
```

Inline documents are matched by title: adding text with the same title again updates the document.

## Supported formats

| Format | Extensions | Conversion |
| --- | --- | --- |
| Markdown | `.md` `.markdown` `.mdx` `.mkd` | kept as is; YAML front matter is removed and provides `title` and `tags`/`keywords`; otherwise the first `#` heading is the title |
| Text | `.txt` `.text` `.log` `.rst` `.adoc` `.asciidoc` `.org` `.textile` | kept as is; the file name is the title |
| Html | `.html` `.htm` `.xhtml` | see [HTML conversion](#html-conversion) |
| Docx | `.docx` | see [Word conversion](#word-conversion) |
| Pdf | `.pdf` | text extraction, see [PDF support](#pdf-support) |
| Csv | `.csv` `.tsv` | Markdown table; the delimiter of `.csv` files (`,`, `;` or tab) is detected from the first line |
| Json | `.json` `.jsonc` `.json5` `.jsonl` | fenced `json` code block |
| Yaml | `.yaml` `.yml` | fenced `yaml` code block |
| Xml | `.xml` `.xsd` `.xsl` `.xslt` `.config` `.csproj` `.props` `.targets` `.resx` `.svg` | fenced `xml` code block |
| Code | `.ps1` `.psm1` `.psd1` `.py` `.js` `.ts` `.cs` `.java` `.go` `.rs` `.sql` `.sh` `.bat` `.tf` `.bicep` `.ini` `.toml` and many more | fenced code block with the language; the file name is the title |

Files without a known extension are imported as text when their first 8 KB contain no NUL bytes; binary files
without a converter are rejected. The well-known file names `Dockerfile`, `Makefile`, `Jenkinsfile`, `Vagrantfile`,
`Gemfile`, `Rakefile` and `Procfile` are imported as code. `Get-McpDocumentConverter` lists all converters and
extensions.

### Markdown front matter

```markdown
---
title: Installation guide
tags: [setup, windows]
---
# Installation
```

Tags can also be written as a YAML list (`tags:` followed by `- setup` lines) or as `keywords`.

### HTML conversion

- The `<main>` element is used when present, otherwise `<article>`, otherwise `<body>`.
- Scripts, styles, `noscript`, `svg`, templates, iframes, navigation, footers, forms, buttons and `aside` elements
  are removed. Headers are kept only when they contain headings.
- Headings, paragraphs, lists, bold and italic text, inline code, links, horizontal rules and block quotes are
  converted to Markdown; `<pre>` blocks become fenced code blocks with the language from a `language-*` class.
- Tables become Markdown tables; HTML entities are decoded.
- The `<title>` element is the document title and is added as heading when the page has no level-one heading.

### Word conversion

Word documents are read with .NET only; Microsoft Word does not need to be installed.

- Headings are detected from the paragraph styles, including localized style names (for example German
  "Überschrift 1"), the Title style and outline levels.
- Numbered and bulleted lists become Markdown lists with indentation for nested levels.
- Tables become Markdown tables.
- The title comes from the document properties (`dc:title`) or the first heading.
- Legacy `.doc` files are not supported; save them as `.docx` first.

### PDF support

PDF text is extracted with one of these tools, in this order:

1. The PowerShell module **PSWritePDF** (`Convert-PDFToText`): `Install-PSResource PSWritePDF`
2. **pdftotext** from Poppler on the `PATH`:
   `winget install oschwartz10612.Poppler`, `brew install poppler` or `apt install poppler-utils`

When neither is available, the import fails with installation instructions. Page breaks become paragraph breaks.
Scanned PDFs without a text layer contain little or no text; run OCR first. PSWritePDF bundles the iText 7 library,
which is licensed under the AGPL; check the license if you redistribute it commercially.

After installing a PDF tool, re-import existing PDF documents with `Update-McpDocument -All -Force`.

## Custom formats

Register a converter for any other format. The script block receives the file path and returns a Markdown string
or a hashtable with `Content` (required), `Title` and `Tags`:

```powershell
Register-McpDocumentConverter -Name Email -Extension .eml -ScriptBlock {
    param($Path)
    $raw = Get-Content -LiteralPath $Path -Raw
    $subject = ([regex]::Match($raw, '(?m)^Subject:\s*(.+)$')).Groups[1].Value
    @{ Title = $subject; Content = "# $subject`n`n" + ($raw -split "`r?`n`r?`n", 2)[1]; Tags = 'mail' }
}
Add-McpDocument -KnowledgeBase Contoso -Path .\mails -Include *.eml -Recurse
```

- Custom converters take precedence over built-in converters for the same extension.
- Registrations last for the current PowerShell session. Put them in your profile to keep them.
- `-Force` replaces an existing custom converter; `Unregister-McpDocumentConverter` removes it.
- Running servers do not need the converter, because documents are converted when they are added.

## Maintaining documents

```powershell
Get-McpDocument -KnowledgeBase Contoso                         # all documents
Get-McpDocument -KnowledgeBase Contoso -Tag runbook            # filter by tag
Get-McpDocument -KnowledgeBase Contoso -Title '*VPN*' -IncludeContent
Get-McpDocument -KnowledgeBase Contoso -Format Pdf -SourceType File

Set-McpDocument -KnowledgeBase Contoso -Id vpn-error-809-1a2b3c -Title 'VPN: error 809' -AddTags network
Set-McpDocument -KnowledgeBase Contoso -Id vpn-error-809-1a2b3c -Content (Get-Content .\vpn.md -Raw)

Update-McpDocument -KnowledgeBase Contoso -All                 # re-import changed files and URLs
Update-McpDocument -KnowledgeBase Contoso -All -RemoveMissing  # also remove documents whose file was deleted
Update-McpDocument -KnowledgeBase Contoso -Id vpn-guide-1a2b3c -Force

Get-McpDocument -KnowledgeBase Contoso -Tag obsolete | Remove-McpDocument
```

- `Update-McpDocument` compares the SHA-256 hash of source files with the hash from the last import and downloads
  URL documents again. Inline documents and agent notes have no source and are skipped.
- `Set-McpDocument -Content` changes the content directly. A later `Update-McpDocument` of a file or URL document
  overwrites manual content changes with the source.
- All changing cmdlets support `-WhatIf` and `-Confirm`.

## Tips for good results

- Use meaningful titles and headings: they are weighted higher in the search and shown to the agent.
- Keep sections focused; long sections are split into chunks of about 1500 characters.
- Use tags for audiences or topics (`runbook`, `faq`, `api`) so agents and you can filter.
- Write a clear knowledge base description; agents use it to decide when to search.
