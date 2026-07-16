# Azure SignalR Client E2E Tests

[![Dev SDK](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Azure/azure-signalr-client-e2e/badges/dev.json&logo=github)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/dev.yml)
[![Stable SDK](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Azure/azure-signalr-client-e2e/badges/stable.json&logo=github)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/stable.yml)

This repository hosts multiple-language client E2E tests for Azure's real-time messaging services. It helps verify that all language clients work correctly in a single pass. Its scope spans two services:

- **Azure SignalR Service** — the .NET, Java, and Swift SignalR clients.
- **Azure Web PubSub** — the JavaScript WebPubSub chat client.

Despite the `azure-signalr` repository name (which predates the Web PubSub coverage), both services are covered here.

Supported clients, grouped by service:

- **Azure SignalR Service:** [.NET](https://github.com/Azure/azure-signalr), [Java](https://github.com/dotnet/aspnetcore/tree/main/src/SignalR/clients/java/signalr), [Swift](https://github.com/dotnet/signalr-client-swift/)
- **Azure Web PubSub:** [JavaScript chat client](https://github.com/Azure/azure-webpubsub/tree/main/sdk/webpubsub-chat-client) — see [`webpubsub/javascript/chatclient/README.md`](./webpubsub/javascript/chatclient/README.md)

## Test Coverage

The client E2E testing aims to cover all combinitions of ASRS Runtime version and Client SDK version:

| | Client SDK (Dev) | Client SDK (Stable) |
|:--|:--|:--|
| **ASRS Runtime (Dev)** | Internal Pipeline | Internal Pipeline |
| **ASRS Runtime (Production)** | GitHub CI | GitHub CI |

> **This repository** covers the bottom row (GitHub CI). The top row is tested by an internal pipeline.
>
> **Scope note:** This matrix models the **Azure SignalR Service** clients (.NET / Java / Swift), whose runtime is Azure SignalR (ASRS). The **JavaScript WebPubSub chat client** targets **Azure Web PubSub** instead, so it runs against the production Web PubSub service with its dev/stable SDK (dev = built from the `webpubsub` submodule, stable = the published npm package) and is not part of the ASRS-runtime matrix above.

## SDK version sources

Each SDK is tested against both a **dev** and a **stable** version:

| Service | SDK | Dev version | Stable version |
|---------|-----|-------------|----------------|
| Azure SignalR Service | .NET | [`Azure/azure-signalr`](https://github.com/Azure/azure-signalr) `dev` branch | Latest stable (non-preview) on [NuGet](https://www.nuget.org/packages/Microsoft.Azure.SignalR) |
| Azure SignalR Service | Java | Latest (including preview) on [Maven Central](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr) | Latest stable (non-preview) on [Maven Central](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr) |
| Azure SignalR Service | Swift | [`dotnet/signalr-client-swift`](https://github.com/dotnet/signalr-client-swift) `dev` branch | Latest stable (non-preview) [GitHub tag](https://github.com/dotnet/signalr-client-swift/tags) |
| Azure Web PubSub | JavaScript chat client | [`Azure/azure-webpubsub`](https://github.com/Azure/azure-webpubsub) `main` branch (`sdk/webpubsub-chat-client`, built from source) | Latest published [`@azure/web-pubsub-chat-client`](https://www.npmjs.com/package/@azure/web-pubsub-chat-client) on npm |

### Version examples

| Service | SDK | Dev version (example) | Stable version (example) |
|---------|-----|----------------------|--------------------------|
| Azure SignalR Service | .NET | [commit `8c944ee9`](https://github.com/Azure/azure-signalr/commit/8c944ee9) (GitHub) | [`1.33.0`](https://www.nuget.org/packages/Microsoft.Azure.SignalR/1.33.0) (NuGet) |
| Azure SignalR Service | Java | [`11.0.0-preview.1.26104.118`](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr/11.0.0-preview.1.26104.118) (Maven Central) | [`10.0.3`](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr/10.0.3) (Maven Central) |
| Azure SignalR Service | Swift | [commit `dd96829`](https://github.com/dotnet/signalr-client-swift/commit/dd96829) (GitHub) | [tag `v1.0.0`](https://github.com/dotnet/signalr-client-swift/releases/tag/v1.0.0) (GitHub) |
| Azure Web PubSub | JavaScript chat client | [`Azure/azure-webpubsub@main`](https://github.com/Azure/azure-webpubsub/tree/main/sdk/webpubsub-chat-client) (GitHub submodule) | [`1.0.0-beta.2`](https://www.npmjs.com/package/@azure/web-pubsub-chat-client) (npm) |

The exact versions tested in each run are recorded in the release notes: [Dev SDK releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=dev-) · [Stable SDK releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=stable-).

## Releases

Each CI run publishes a **GitHub Release** containing pre-built test artifacts (`e2e-artifacts-{dev,stable}.tar.gz`). The archive includes the compiled test server, .NET / Java / Swift test binaries, the JavaScript WebPubSub chat client harness (with `node_modules`), and `run-from-artifacts.sh` so tests can be re-run without rebuilding.

| Release | Description |
|---------|-------------|
| [`latest-dev`](https://github.com/Azure/azure-signalr-client-e2e/releases/tag/latest-dev) | Always points to the most recent Dev SDK run |
| [`latest-stable`](https://github.com/Azure/azure-signalr-client-e2e/releases/tag/latest-stable) | Always points to the most recent Stable SDK run |
| `dev-YYYYMMDD-HHMMSS` | Timestamped history for each Dev run |
| `stable-YYYYMMDD-HHMMSS` | Timestamped history for each Stable run |

Release notes record the exact SDK versions tested. Browse all: [Dev releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=dev-) · [Stable releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=stable-).


## Cloning with submodules

The Swift client, .NET SDK, and JavaScript WebPubSub chat client SDK are included as Git submodules. Always clone the repository with submodules enabled:

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
- Swift toolchain: >= 6.0
- Node.js: >= 20 (JavaScript WebPubSub chat client tests)

You can either install them manually or run the provided script.
- Automated install (Recommended): 

  Run `./install-prerequisite.sh`

- Manual install:

  Just make sure each tool is on PATH and meets the versions above.

### Quick verification
```bash
dotnet --version; javac -version; mvn -v | head -n1; swift --version; node --version
```

## Running the tests

### 1. Build artifacts

```bash
./build-artifacts.sh
```

This compiles the test server, .NET / Java / Swift test binaries, and the JavaScript WebPubSub chat client harness into `./artifacts/`.

By default the JavaScript WebPubSub chat client SDK is built from the `webpubsub` submodule (dev). To build against the published npm package instead, set `JAVASCRIPT_CHATCLIENT_SDK_SOURCE=npm` (optionally with `JAVASCRIPT_CHATCLIENT_SDK_VERSION=<version>`).

### 2. Run tests from artifacts

```bash
export E2E_SIGNALR_CONNECTION_STRING_DEFAULT="<your-azure-signalr-connection-string>"
# Optional — enables the JavaScript WebPubSub chat client suite:
export E2E_WEBPUBSUB_CHAT_CONNECTION_STRING="<your-azure-web-pubsub-connection-string>"
./run-from-artifacts.sh
```

The script starts a local test server, runs all test suites (Java, Swift, .NET, JavaScript WebPubSub chat client), and exits with a non-zero code if any suite fails.

> **Note:** .NET tests do **not** use the local test server. They spin up an in-process Kestrel server that connects directly to Azure SignalR Service via `AddAzureSignalR()`. Java and Swift tests connect through the local test server. The JavaScript WebPubSub chat client tests target **Azure Web PubSub** through their own local negotiate server and are **skipped** when `E2E_WEBPUBSUB_CHAT_CONNECTION_STRING` is not set.

## CI Workflows

Three workflows run in sequence: **Sync Submodules** → **Client E2E (Dev SDK)** → **Client E2E (Stable SDK)**.

Triggered by every push to `master`, daily at 00:00 UTC, or manually.

- **Re-run a failed test**: Click a badge above → open the failed run → **Re-run failed jobs**.
- **Manually trigger**: Click a badge above → **Run workflow**.
