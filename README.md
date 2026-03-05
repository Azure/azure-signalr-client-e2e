# Azure SignalR Client E2E Tests

[![Dev SDK](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Azure/azure-signalr-client-e2e/badges/dev.json&logo=github)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/dev.yml)
[![Stable SDK](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Azure/azure-signalr-client-e2e/badges/stable.json&logo=github)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/stable.yml)

This repository hosts multiple languages client E2E tests for Azure SignalR. It helps verify all language clients work correctly with Azure SignalR Service in a single pass.

- Supported clients: [Java](https://github.com/dotnet/aspnetcore/tree/main/src/SignalR/clients/java/signalr), [Swift](https://github.com/dotnet/signalr-client-swift/), [.NET](https://github.com/Azure/azure-signalr)

## SDK version sources

Each SDK has a **stable version** (latest release on its registry) and a **dev version** (latest commit on its development branch). The E2E tests run against **both** — see the two badges above.

| SDK | Dev version | Stable version |
|-----|-------------|----------------|
| .NET | [`Azure/azure-signalr`](https://github.com/Azure/azure-signalr) `dev` branch | Latest stable (non-preview) on [NuGet](https://www.nuget.org/packages/Microsoft.Azure.SignalR) |
| Java | Latest (including preview) on [Maven Central](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr) | Latest stable (non-preview) on [Maven Central](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr) |
| Swift | [`dotnet/signalr-client-swift`](https://github.com/dotnet/signalr-client-swift) `dev` branch | Latest stable (non-preview) [GitHub tag](https://github.com/dotnet/signalr-client-swift/tags) |

### Version examples

| SDK | Dev version (example) | Stable version (example) |
|-----|----------------------|--------------------------|
| .NET | [commit `8c944ee9`](https://github.com/Azure/azure-signalr/commit/8c944ee9) (GitHub) | [`1.33.0`](https://www.nuget.org/packages/Microsoft.Azure.SignalR/1.33.0) (NuGet) |
| Java | [`11.0.0-preview.1.26104.118`](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr/11.0.0-preview.1.26104.118) (Maven Central) | [`10.0.3`](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr/10.0.3) (Maven Central) |
| Swift | [commit `dd96829`](https://github.com/dotnet/signalr-client-swift/commit/dd96829) (GitHub) | [tag `v1.0.0`](https://github.com/dotnet/signalr-client-swift/releases/tag/v1.0.0) (GitHub) |

The exact versions tested in each run are recorded in the release notes: [Dev SDK releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=dev-) · [Stable SDK releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=stable-).

## Cloning with submodules

The Swift client and .NET SDK are included as Git submodules. Always clone the repository with submodules enabled:

```bash
git clone --recurse-submodules https://github.com/Azure/azure-signalr-client-e2e.git
```

If you already cloned without submodules, run:

```bash
git submodule update --init --recursive
```

## Install Prerequisites
### Requirements
- .NET SDK: 8.0
- Java JDK: OpenJDK 21
- Maven: >= 3.6.3
- Swift toolchain: >= 5.10

You can either install them manually or run the provided script.
- Automated install (Recommended): 

  Run `./install-prerequisite.sh`

- Manual install:

  Just make sure each tool is on PATH and meets the versions above.

### Quick verification
```bash
dotnet --version
javac -version
mvn -v | head -n1
swift --version
```

## Running the test suites
- Get the connection string for your Azure SignalR resource from Azure portal or CLI.
- From the repository root, execute:
```bash
export E2E_CONNECTION_STRING="<your-azure-signalr-connection-string>"
./run-all-tests.sh
```

The script:
- Starts a local test server at `http://localhost:8080/test` (from `server/`)
- Runs the Java tests (`mvn -Dtest=IntegrationTests test` in `java/`)
- Runs the Swift tests (`swift test --filter SignalRClientIntegrationTests` in `swift/`)
- Runs the .NET tests (`dotnet test` in `dotnet/test/Microsoft.Azure.SignalR.E2ETests/`)
- Emits a non-zero exit code when any suite fails

## CI Workflows

There are three CI workflows that run in sequence (see badges at the top):

| Workflow | Trigger | What it does |
|----------|---------|------------|
| **Sync Submodules** | Every push to `master` + daily 00:00 UTC | Syncs submodules to upstream HEAD, updates Java SDK version |
| **Client E2E (Dev SDK)** | After Sync Submodules completes | Builds & tests with dev submodule HEAD + latest preview Java |
| **Client E2E (Stable SDK)** | After Dev SDK completes | Resolves latest stable versions from NuGet / Maven / GitHub tags, builds & tests |

Each test workflow runs 5 test jobs in parallel: .NET (Default Mode), .NET (Serverless Mode), Java, Swift (Ubuntu), Swift (macOS). The badges show how many tests passed (e.g. "5/5 passed"); badge data is stored on the `badges` branch and updated automatically after each run.

- **Check which SDK version was tested**: [Dev releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=dev-) · [Stable releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=stable-)
- **Re-run a failed test**: Click the badge → open the failed run → click **Re-run failed jobs**.
- **Manually trigger**: Click the badge → click **Run workflow** on the workflow page.