# syntax=docker/dockerfile:1
#
# MCPPosh MCP server (Streamable HTTP) for central hosting, e.g. Azure Container Apps.
# The MCPPosh module is installed from the PowerShell Gallery.
#
# Build (from the repository root):
#   docker build -f docker/Dockerfile -t mcpposh .                                     # latest version from the Gallery
#   docker build -f docker/Dockerfile --build-arg MCPPOSH_VERSION=0.1.0 -t mcpposh .   # specific version
#   docker build -f docker/Dockerfile --build-arg MCPPOSH_SOURCE=Local -t mcpposh .    # package from docker/packages
# Run:
#   docker run -p 8080:8080 -e MCPPOSH_API_KEY=change-me -v mcpposh-data:/data mcpposh

ARG PWSH_VERSION=7.4.6
ARG TARGETARCH=amd64

# PowerShell release archives, one stage per architecture (only the target architecture is built).
FROM scratch AS pwsh-amd64
ARG PWSH_VERSION
ADD https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz /powershell.tar.gz

FROM scratch AS pwsh-arm64
ARG PWSH_VERSION
ADD https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-arm64.tar.gz /powershell.tar.gz

FROM pwsh-${TARGETARCH} AS pwsh

FROM mcr.microsoft.com/dotnet/runtime-deps:8.0-bookworm-slim

ARG TARGETARCH
# SHA-256 of the PowerShell release archives (hashes.sha256 of the GitHub release). Update them
# together with PWSH_VERSION; the build fails when the downloaded archive does not match.
ARG PWSH_SHA256_AMD64=6f6015203c47806c5cc444c19d8ed019695e610fbd948154264bf9ca8e157561
ARG PWSH_SHA256_ARM64=c0159b03e85f44ae1e7697818a011558da6c813d0aae848bf5ac13bf435d8624

# PSGallery (default) or Local (nupkg files in docker/packages, e.g. from ./build.ps1 -Tasks pack).
ARG MCPPOSH_SOURCE=PSGallery
# Empty = latest stable version.
ARG MCPPOSH_VERSION=

COPY --from=pwsh /powershell.tar.gz /tmp/powershell.tar.gz
RUN case "${TARGETARCH:-amd64}" in \
        amd64) expected="${PWSH_SHA256_AMD64}" ;; \
        arm64) expected="${PWSH_SHA256_ARM64}" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && echo "${expected}  /tmp/powershell.tar.gz" | sha256sum -c - \
    && mkdir -p /opt/microsoft/powershell/7 \
    && tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 \
    && chmod +x /opt/microsoft/powershell/7/pwsh \
    && ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh \
    && rm /tmp/powershell.tar.gz

ENV POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    MCPPOSH_HOME=/data \
    MCPPOSH_KNOWLEDGEBASE=Default \
    MCPPOSH_PORT=8080

COPY docker/Install-MCPPosh.ps1 /tmp/install/Install-MCPPosh.ps1
COPY docker/packages/ /tmp/install/packages/
RUN pwsh -NoLogo -NoProfile -NonInteractive -File /tmp/install/Install-MCPPosh.ps1 \
        -Source "${MCPPOSH_SOURCE}" -Version "${MCPPOSH_VERSION}" -PackagePath /tmp/install/packages \
    && rm -rf /tmp/install

COPY docker/entrypoint.ps1 /app/entrypoint.ps1

# 'app' (uid 1654) is the non-root user of the .NET base images.
RUN mkdir -p /data /seed && chown -R app:app /data

USER app
VOLUME ["/data"]
EXPOSE 8080

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-File", "/app/entrypoint.ps1"]
