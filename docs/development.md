# Development

MCPPosh is built, tested, documented and released with [Sampler](https://github.com/gaelcolas/Sampler), the
PowerShell module build framework based on InvokeBuild, ModuleBuilder, Pester and PlatyPS.

## Requirements

- PowerShell 7.2 or later
- Git
- Access to the PowerShell Gallery (the build downloads its dependencies into `output/RequiredModules`)
- Optional: the .NET SDK for `pack` and `publish`, GitVersion for version calculation, Docker for the image

## Build tasks

```powershell
./build.ps1 -ResolveDependency -Tasks noop   # download the build dependencies (once, or after RequiredModules.psd1 changes)
./build.ps1 -Tasks build                     # build the module into output/module/MCPPosh/<version>
./build.ps1 -Tasks test                      # QA, unit and integration tests with code coverage
./build.ps1 -Tasks build, docs               # regenerate the cmdlet reference in docs/en-US
./build.ps1 -Tasks pack                      # build and create output/MCPPosh.<version>.nupkg (requires the .NET SDK)
./build.ps1                                  # default workflow: build and test
```

The workflows are defined in `build.yaml`:

| Workflow | Tasks |
| --- | --- |
| `build` | `Clean`, `Build_Module_ModuleBuilder`, `Build_NestedModules_ModuleBuilder`, `Create_changelog_release_output` |
| `pack` | `build`, `package_module_nupkg` |
| `docs` | `Update_markdown_help_source`, `Remove_ProgressAction_From_Markdown_Help` |
| `test` | `Pester_Tests_Stop_On_Fail`, `Pester_if_Code_Coverage_Under_Threshold` |
| `publish` | `Publish_Release_To_GitHub`, `publish_module_to_gallery` |

Custom tasks live in `.build/` and are loaded by `build.ps1` automatically.

## Repository layout

```text
source/                      module source
  MCPPosh.psd1               module manifest (version and exports are set by the build)
  MCPPosh.psm1               placeholder; the build creates the real root module
  prefix.ps1                 module state placed at the top of the built psm1
  suffix.ps1                 initialization placed at the end of the built psm1
  Public/<area>/<Verb-Noun>.ps1    exported cmdlets, one per file
  Private/<area>/<Verb-Noun>.ps1   internal functions, one per file
  en-US/about_MCPPosh.help.txt     conceptual help
tests/
  QA/                        Sampler quality tests and documentation checks
  Unit/Public, Unit/Private  one test file per function
  Integration/               real stdio and HTTP server processes
  TestHelpers/               shared test helpers
docs/                        guides and the generated cmdlet reference (docs/en-US)
docker/                      Dockerfile, entry point and installation script
deploy/azure/                Bicep template and deployment script
examples/                    example scripts
.build/                      custom Sampler tasks
build.ps1, build.yaml, RequiredModules.psd1, Resolve-Dependency.*, GitVersion.yml   Sampler build files
```

ModuleBuilder merges `prefix.ps1`, all files in `Private` and `Public` and `suffix.ps1` into one `MCPPosh.psm1` and
exports the functions in `Public` (the file name is the function name).

## Coding rules

The Sampler QA tests (`tests/QA/module.tests.ps1`) enforce for **every** function, public and private:

- one function per file, named like the function,
- comment-based help with `.SYNOPSIS`, a `.DESCRIPTION` longer than 40 characters, at least one `.EXAMPLE` that uses
  the function and a description of more than 25 characters for every parameter,
- a unit test file `tests/Unit/**/<Function>.Tests.ps1`,
- no PSScriptAnalyzer findings with the default rules. Suppress a rule only with
  `[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]` and a justification.

Public cmdlets additionally document `.INPUTS`, `.OUTPUTS` and `.LINK` (the first link is the online reference page).
Use approved verbs, `SupportsShouldProcess` for changing cmdlets and English for all code, comments and messages.
Keep source files ASCII-only; use `[char]` escapes for other characters.

## Tests

```powershell
./build.ps1 -Tasks test
```

- Tests run against the built module in `output/module`, which the build puts first on `PSModulePath`.
- Each test file imports `tests/TestHelpers/MCPPosh.TestHelpers.psm1`, which creates an isolated `MCPPOSH_HOME`.
- Private functions are tested with `InModuleScope MCPPosh`.
- Code coverage must be at least 85 % (`CoveragePercentTarget` in `build.yaml`).
- To run a single test file after a build:

  ```powershell
  $env:PSModulePath = (Resolve-Path ./output/module).Path + [IO.Path]::PathSeparator + $env:PSModulePath
  Import-Module ./output/RequiredModules/Pester
  Invoke-Pester ./tests/Unit/Public/Add-McpDocument.Tests.ps1 -Output Detailed
  ```

## Documentation

- Guides are hand-written Markdown in `docs/`.
- The cmdlet reference in `docs/en-US` is generated from the comment-based help with PlatyPS. After changing help,
  run `./build.ps1 -Tasks build, docs` and commit the changes. The module page `docs/en-US/MCPPosh.md` is maintained
  by hand.
- `tests/QA/docs.tests.ps1` checks that every cmdlet has a reference page whose synopsis matches the help, that no
  placeholders are left and that relative links resolve.
- Markdown style is checked with `npx markdownlint-cli2` (configuration in `.markdownlint.json` and
  `.markdownlint-cli2.jsonc`).

## Changelog

Every change needs an entry in the `Unreleased` section of [CHANGELOG.md](../CHANGELOG.md) following
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/). The QA tests check the format; the build turns the entry
into the release notes of the module.

## Versioning and releases

The version is calculated by [GitVersion](https://gitversion.net) from the Git history (`GitVersion.yml`, mode
ContinuousDelivery): `main` builds preview versions, a tag `vX.Y.Z` produces the release version `X.Y.Z`.

The workflow [`.github/workflows/build.yml`](../.github/workflows/build.yml) runs for every push and pull request:

| Job | What it does |
| --- | --- |
| `build` | GitVersion, `./build.ps1 -Tasks pack`, uploads `output` as artifact |
| `test` | `./build.ps1 -Tasks test` on Windows, Linux and macOS |
| `analyze` | Bicep build, PSScriptAnalyzer for `docker` and `deploy`, Markdown lint |
| `docker` | builds the image from the built package and runs a smoke test (not for tags) |
| `publish` | tags only: `./build.ps1 -Tasks publish` to the PowerShell Gallery and GitHub releases |
| `docker-release` | tags only: builds the multi-architecture image from the Gallery and pushes it to `ghcr.io/<owner>/mcpposh` |

To release a version:

1. Make sure `CHANGELOG.md` describes the changes under `Unreleased`.
2. Create the repository secret `GALLERY_API_TOKEN` with a PowerShell Gallery API key (once).
3. Tag the commit on `main` and push the tag:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
