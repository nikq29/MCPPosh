# Hosting with Docker

The Docker image runs an MCPPosh HTTP server for central hosting. The module is installed from the PowerShell
Gallery, so the image always contains a released version.

## Quick start

```bash
docker run -d --name mcpposh -p 8080:8080 \
  -e MCPPOSH_API_KEY=change-me-to-a-long-random-key \
  -e MCPPOSH_KNOWLEDGEBASE=Contoso \
  -e MCPPOSH_DESCRIPTION="Internal IT documentation of Contoso" \
  -v mcpposh-data:/data \
  ghcr.io/nikq29/mcpposh:latest

curl -s -H "Authorization: Bearer change-me-to-a-long-random-key" http://localhost:8080/health
```

The MCP endpoint is `http://localhost:8080/mcp`. Released images are published to `ghcr.io/nikq29/mcpposh` with the
module version as tag (for example `0.1.0`) and `latest` for stable versions, for `linux/amd64` and `linux/arm64`.

## Image contents

- Base image `mcr.microsoft.com/dotnet/runtime-deps:8.0-bookworm-slim`.
- PowerShell from the official release archive for the target architecture (`PWSH_VERSION`, default 7.4.6).
- MCPPosh installed for all users with PSResourceGet by `docker/Install-MCPPosh.ps1`.
- Entry point `docker/entrypoint.ps1`, which creates the knowledge base if needed, imports seed documents and starts
  `Start-McpServer -Transport Http -ListenAddress '*' -Foreground`.
- Runs as the non-root user `app` (uid and gid 1654); `/data` belongs to this user.
- Exposes port 8080 and declares the volume `/data`.

## Environment variables

| Variable | Meaning | Default |
| --- | --- | --- |
| `MCPPOSH_API_KEY` | API key(s), comma-separated | required |
| `MCPPOSH_KNOWLEDGEBASE` | knowledge base to serve | `Default` |
| `MCPPOSH_DESCRIPTION` | description used when the knowledge base is created | empty |
| `MCPPOSH_PORT` | port inside the container | `8080` |
| `MCPPOSH_ALLOW_WRITE` | `true` enables the `add_note` tool | `false` |
| `MCPPOSH_ALLOW_ANONYMOUS` | `true` runs without API key (only behind an authenticating gateway) | `false` |
| `MCPPOSH_ALLOWED_ORIGINS` | comma-separated browser origins for CORS | empty |
| `MCPPOSH_IMPORT_PATH` | folder whose documents are imported at start | `/seed` |
| `MCPPOSH_HOME` | data directory | `/data` |

Boolean variables accept `1`, `true`, `yes` and `on`.

## Data and documents

The knowledge base lives in `/data/knowledgebases/<name>`. Mount a volume or a host folder at `/data` to keep it:

```bash
docker run -d -p 8080:8080 -e MCPPOSH_API_KEY=... -v /srv/mcpposh:/data ghcr.io/nikq29/mcpposh:latest
```

There are three ways to fill the knowledge base:

1. **Seed folder**: mount a folder with documents at `/seed`. All files are imported (or updated) at every start.

   ```bash
   docker run -d -p 8080:8080 -e MCPPOSH_API_KEY=... -v ./docs:/seed:ro -v mcpposh-data:/data ghcr.io/nikq29/mcpposh:latest
   ```

2. **Shared data folder**: mount the same host folder at `/data` and set `$env:MCPPOSH_HOME` to it on the host; then
   use `Add-McpDocument` on the host. The server reloads within a second. The host folder must be writable for uid
   1654.
3. **Azure Files**: publish a local knowledge base with `Publish-McpKnowledgeBase`, see [Azure](hosting-azure.md).

## Building the image

Build from the repository root. Only the `docker` folder is part of the build context (see `.dockerignore`).

```bash
docker build -f docker/Dockerfile -t mcpposh .                                     # latest stable version from the Gallery
docker build -f docker/Dockerfile --build-arg MCPPOSH_VERSION=0.1.0 -t mcpposh .   # a specific version
```

| Build argument | Meaning | Default |
| --- | --- | --- |
| `MCPPOSH_SOURCE` | `PSGallery` or `Local` | `PSGallery` |
| `MCPPOSH_VERSION` | module version, empty for the latest stable version; prerelease versions such as `0.2.0-preview0003` are supported | empty |
| `PWSH_VERSION` | PowerShell version | `7.4.6` |

When a specific version is requested from the Gallery, the installation is retried for up to ten minutes, because a
freshly published version can take a few minutes to become available.

### Testing an unreleased build

Build and package the module with Sampler, copy the package into `docker/packages` and build with
`MCPPOSH_SOURCE=Local`:

```powershell
./build.ps1 -ResolveDependency -Tasks pack
Copy-Item output/MCPPosh.*.nupkg docker/packages/
docker build -f docker/Dockerfile --build-arg MCPPOSH_SOURCE=Local -t mcpposh:dev .
```

The CI workflow does the same for every push and pull request and runs a smoke test against the container.

## Docker Compose

```yaml
services:
  mcpposh:
    image: ghcr.io/nikq29/mcpposh:latest
    ports:
      - "8080:8080"
    environment:
      MCPPOSH_API_KEY: ${MCPPOSH_API_KEY}
      MCPPOSH_KNOWLEDGEBASE: Contoso
      MCPPOSH_DESCRIPTION: Internal IT documentation of Contoso
    volumes:
      - mcpposh-data:/data
      - ./docs:/seed:ro
    healthcheck:
      test: ["CMD", "pwsh", "-NoProfile", "-Command", "try { Invoke-RestMethod http://localhost:8080/health | Out-Null } catch { exit 1 }"]
      interval: 30s
      timeout: 10s
      retries: 3
volumes:
  mcpposh-data:
```

## Operations

- Logs: `docker logs mcpposh` shows the server log (one line per request).
- TLS: the container serves plain HTTP. Put a reverse proxy or a platform ingress with TLS in front of it.
- Updates: pull the new image and recreate the container; the knowledge base in `/data` is kept.
- Scaling: the server is stateless. Several containers can share a read-only knowledge base; with `add_note` keep a
  single container.
