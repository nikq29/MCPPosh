# syntax=docker/dockerfile:1
#
# PSMcpKnowledgeBase MCP server (Streamable HTTP) for central hosting, e.g. Azure Container Apps.
# The PSMcpKnowledgeBase module is installed from the PowerShell Gallery.
#
# Build (from the repository root):
#   docker build -f docker/Dockerfile -t psmcpkb .                                     # latest version from the Gallery
#   docker build -f docker/Dockerfile --build-arg PSMCPKB_VERSION=0.1.0 -t psmcpkb .   # specific version
#   docker build -f docker/Dockerfile --build-arg PSMCPKB_SOURCE=Local -t psmcpkb .    # package from docker/packages
# Run:
#   docker run -p 8080:8080 -e PSMCPKB_API_KEY=change-me -v psmcpkb-data:/data psmcpkb

ARG PWSH_VERSION=7.6.10
# Set by BuildKit for each target platform (amd64, arm64). Do not give it a default: a default
# replaces the automatic value, and a multi-platform build would put the x64 PowerShell into
# the arm64 image.
ARG TARGETARCH

# PowerShell release archives, one stage per architecture (only the target architecture is built).
FROM scratch AS pwsh-amd64
ARG PWSH_VERSION
ADD https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz /powershell.tar.gz

FROM scratch AS pwsh-arm64
ARG PWSH_VERSION
ADD https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-arm64.tar.gz /powershell.tar.gz

FROM pwsh-${TARGETARCH} AS pwsh

FROM mcr.microsoft.com/dotnet/runtime-deps:10.0-trixie-slim

# Pick up security fixes published after the base image was built.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
# SHA-256 of the PowerShell release archives (hashes.sha256 of the GitHub release). Update them
# together with PWSH_VERSION; the build fails when the downloaded archive does not match.
ARG PWSH_SHA256_AMD64=e261cabc91c78a9afe8d1e5f24731ab0d38204735ab2ec94b0af55102652e10d
ARG PWSH_SHA256_ARM64=439432cdecf4418413b9a8f547e3ab4d9b40e8e4258913ec3d15fc92c67a9235

# PSGallery (default) or Local (nupkg files in docker/packages, e.g. from ./build.ps1 -Tasks pack).
ARG PSMCPKB_SOURCE=PSGallery
# Empty = latest stable version.
ARG PSMCPKB_VERSION=

COPY --from=pwsh /powershell.tar.gz /tmp/powershell.tar.gz
RUN case "${TARGETARCH}" in \
        amd64) expected="${PWSH_SHA256_AMD64}" ;; \
        arm64) expected="${PWSH_SHA256_ARM64}" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && echo "${expected}  /tmp/powershell.tar.gz" | sha256sum -c - \
    && mkdir -p /opt/microsoft/powershell/7 \
    && tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 \
    && chmod +x /opt/microsoft/powershell/7/pwsh \
    && ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh \
    && rm /tmp/powershell.tar.gz \
    && pwsh -NoLogo -NoProfile -Version

ENV POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    PSMCPKB_HOME=/data \
    PSMCPKB_KNOWLEDGEBASE=Default \
    PSMCPKB_PORT=8080

COPY docker/Install-PSMcpKnowledgeBase.ps1 /tmp/install/Install-PSMcpKnowledgeBase.ps1
COPY docker/packages/ /tmp/install/packages/
RUN pwsh -NoLogo -NoProfile -NonInteractive -File /tmp/install/Install-PSMcpKnowledgeBase.ps1 \
        -Source "${PSMCPKB_SOURCE}" -Version "${PSMCPKB_VERSION}" -PackagePath /tmp/install/packages \
    && rm -rf /tmp/install

COPY docker/entrypoint.ps1 /app/entrypoint.ps1

# 'app' (uid 1654) is the non-root user of the .NET base images.
RUN mkdir -p /data /seed && chown -R app:app /data

USER app
VOLUME ["/data"]
EXPOSE 8080

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-File", "/app/entrypoint.ps1"]
