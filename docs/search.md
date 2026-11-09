# Search

MCPPosh ships a local full-text search based on [BM25](https://en.wikipedia.org/wiki/Okapi_BM25). It needs no API
keys, no embedding model and no network access. `Search-McpDocument` and the MCP tool `search_documentation` use the
same search.

```powershell
Search-McpDocument -KnowledgeBase Contoso -Query 'vpn connection drops'
Search-McpDocument -KnowledgeBase Contoso -Query 'certificate' -Tag vpn -Top 3 | Format-List Title, Heading, Text
```

Each result contains `Score`, `DocumentId`, `Title`, `Heading`, `Tags`, `Source`, `Snippet` (about 240 characters
around the first match) and `Text` (the complete section).

## Chunking

Documents are split into sections at Markdown headings. Headings inside fenced code blocks are ignored. Each section
keeps its heading path, for example `Installation > Requirements`, so the agent knows where a result comes from.
Sections longer than 1500 characters are split at paragraph boundaries, then at line boundaries; only single lines
longer than the limit are cut.

## Tokenization

Text is turned into search terms as follows:

1. Lowercase; the German sharp s (ß) becomes `ss`; diacritics are removed (`ü` becomes `u`).
2. The text is split into words of letters and digits.
3. Words shorter than two characters and common English and German stop words are dropped.
4. Common English and German suffixes (`ungen`, `heiten`, `keiten`, `ingen`, `ung`, `heit`, `keit`, `ing`, `ies`,
   `ern`, `en`, `er`, `es`, `ed`, `e`, `s`) are stripped repeatedly from words with at least five characters, as long
   as at least three characters remain. This makes `server`, `servers` and `Server-Konfigurationen` match.

## Ranking

- Every section is scored with BM25 (k1 = 1.2, b = 0.75). Terms in the heading path count twice, terms of the
  document title count once in every section of the document.
- Query terms that do not occur in the index are expanded to up to 20 indexed terms with the same prefix (for example
  `konfig` finds `konfiguration`), with a reduced weight.
- Sections that contain more of the distinct query terms get a small boost.
- At most three sections per document are returned, so results cover several documents.
- `-Tag` (or the tool argument `tags`) restricts the search to documents with at least one of the tags.

## Index storage and caching

The term frequencies of each document are computed when the document is added and stored in `index/<id>.json`.
The search loads these files into memory once and caches the index until `manifest.json` changes. Missing or
damaged index files are rebuilt from the document content automatically.

As a guide, 300 documents with 1.6 MB of text import in about 20 seconds; the first search including loading the
index takes about half a second, further searches take a few tens of milliseconds.

## Tips

- Search with specific keywords from your documentation rather than long sentences. Stop words are ignored anyway.
- Check the ranking with `Search-McpDocument` before you connect agents, and improve titles and headings where the
  right section does not come first.
- Split very large documents into topic-specific documents or sections.
- The search does not understand synonyms. Mention important alternative terms in the text, for example
  "VPN (virtual private network)".
