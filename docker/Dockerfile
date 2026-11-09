# MCPPosh MCP server (Streamable HTTP) for central hosting, e.g. Azure Container Apps.
#
# Build (from the repository root):
#   docker build -f docker/Dockerfile -t mcpposh:latest .
# Run:
#   docker run -p 8080:8080 -e MCPPOSH_API_KEY=change-me -v mcpposh-data:/data mcpposh:latest

FROM mcr.microsoft.com/dotnet/runtime-deps:8.0-bookworm-slim

ARG PWSH_VERSION=7.4.6
ARG TARGETARCH

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl less locales tzdata; \
    case "${TARGETARCH:-amd64}" in \
        amd64) PWSH_ARCH=x64 ;; \
        arm64) PWSH_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/powershell.tar.gz "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${PWSH_ARCH}.tar.gz"; \
    mkdir -p /opt/microsoft/powershell/7; \
    tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7; \
    chmod +x /opt/microsoft/powershell/7/pwsh; \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh; \
    rm /tmp/powershell.tar.gz; \
    apt-get purge -y --auto-remove curl; \
    rm -rf /var/lib/apt/lists/*

ENV POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    MCPPOSH_HOME=/data \
    MCPPOSH_KNOWLEDGEBASE=Default \
    MCPPOSH_PORT=8080

COPY src/MCPPosh /usr/local/share/powershell/Modules/MCPPosh
COPY docker/entrypoint.ps1 /app/entrypoint.ps1

# 'app' (uid 1654) is the non-root user of the .NET base images.
RUN mkdir -p /data /seed && chown -R app:app /data

USER app
VOLUME ["/data"]
EXPOSE 8080

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-File", "/app/entrypoint.ps1"]
