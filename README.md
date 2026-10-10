# Azure Real-time Messaging Services E2E Tests

[![Dev SDK](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Azure/azure-signalr-client-e2e/badges/dev.json&logo=github)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/dev.yml)
[![Stable SDK](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Azure/azure-signalr-client-e2e/badges/stable.json&logo=github)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/stable.yml)

This repository runs E2E tests for packages across Azure's real-time messaging services:

| Service | Covered Packages |
|---------|------------------|
| **Azure SignalR Service** | [.NET Server SDK](https://github.com/Azure/azure-signalr), [Java Client](https://github.com/dotnet/aspnetcore/tree/main/src/SignalR/clients/java/signalr), [Swift Client](https://github.com/dotnet/signalr-client-swift/) |
| **Azure Web PubSub** | [JavaScript Chat Client](https://github.com/Azure/azure-webpubsub/tree/main/sdk/webpubsub-chat-client), [JavaScript Socket.IO Extension](https://github.com/Azure/azure-webpubsub/tree/main/sdk/webpubsub-socketio-extension) |

Despite the `azure-signalr` repository name (which predates the Web PubSub coverage), both services are covered here.

## Test Coverage

The Azure SignalR Service E2E tests aim to cover all combinations of ASRS runtime and package versions:

| | Package (Dev) | Package (Stable) |
|:--|:--|:--|
| **ASRS Runtime (Dev)** | Internal Pipeline | Internal Pipeline |
| **ASRS Runtime (Production)** | GitHub CI | GitHub CI |

> **This repository** covers the bottom row (GitHub CI). The top row is tested by an internal pipeline.
>
> This matrix covers **Azure SignalR Service packages** (.NET Server SDK, Java Client, and Swift Client) only. Web PubSub tests run against the production Web PubSub service, not the ASRS runtime.
>
> **.NET test frameworks:** .NET 8 runs in Default and Serverless Mode for both dev and stable SDKs. .NET 11 (preview) currently runs in Default Mode for the dev SDK only.

## Package version sources

Each package is tested against both a **dev** and a **stable** version:

| Service | Package | Dev version | Stable version |
|---------|---------|-------------|----------------|
| Azure SignalR Service | .NET Server SDK | [`Azure/azure-signalr`](https://github.com/Azure/azure-signalr) `dev` branch | Latest stable (non-preview) on [NuGet](https://www.nuget.org/packages/Microsoft.Azure.SignalR) (matching source tag) |
| Azure SignalR Service | Java Client | Latest (including preview) on [Maven Central](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr) | Latest stable (non-preview) on [Maven Central](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr) |
| Azure SignalR Service | Swift Client | [`dotnet/signalr-client-swift`](https://github.com/dotnet/signalr-client-swift) `dev` branch | Latest stable (non-preview) [GitHub tag](https://github.com/dotnet/signalr-client-swift/tags) |
| Azure Web PubSub | JavaScript Chat Client | [`Azure/azure-webpubsub`](https://github.com/Azure/azure-webpubsub) `main` branch (`sdk/webpubsub-chat-client`, built from source) | Latest published [`@azure/web-pubsub-chat-client`](https://www.npmjs.com/package/@azure/web-pubsub-chat-client) on npm |
| Azure Web PubSub | JavaScript Socket.IO Extension | [`Azure/azure-webpubsub`](https://github.com/Azure/azure-webpubsub) `main` branch (`sdk/webpubsub-socketio-extension`, built from source) | Latest published [`@azure/web-pubsub-socket.io`](https://www.npmjs.com/package/@azure/web-pubsub-socket.io) on npm |

The .NET E2E tests also reference [`Microsoft.AspNetCore.SignalR.Client`](https://github.com/dotnet/aspnetcore/tree/main/src/SignalR/clients/csharp/Client/src) from `dotnet/aspnetcore`. Its version is set by the upstream test project; this workflow does not independently switch the .NET Client between dev and stable versions.

### Version references

GitHub dev references follow moving branches; registry versions are examples.

| Service | Package | Dev | Stable |
|---------|---------|-----|--------|
| Azure SignalR Service | .NET Server SDK | [`Azure/azure-signalr@dev`](https://github.com/Azure/azure-signalr/tree/dev) (GitHub submodule) | [`1.33.0`](https://www.nuget.org/packages/Microsoft.Azure.SignalR/1.33.0) (NuGet) |
| Azure SignalR Service | Java Client | [`11.0.0-preview.1.26104.118`](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr/11.0.0-preview.1.26104.118) (Maven Central) | [`10.0.3`](https://central.sonatype.com/artifact/com.microsoft.signalr/signalr/10.0.3) (Maven Central) |
| Azure SignalR Service | Swift Client | [`dotnet/signalr-client-swift@dev`](https://github.com/dotnet/signalr-client-swift/tree/dev) (GitHub submodule) | [tag `v1.0.0`](https://github.com/dotnet/signalr-client-swift/releases/tag/v1.0.0) (GitHub) |
| Azure Web PubSub | JavaScript Chat Client | [`Azure/azure-webpubsub@main`](https://github.com/Azure/azure-webpubsub/tree/main/sdk/webpubsub-chat-client) (GitHub submodule) | [`1.0.0-beta.2`](https://www.npmjs.com/package/@azure/web-pubsub-chat-client) (npm) |
| Azure Web PubSub | JavaScript Socket.IO Extension | [`Azure/azure-webpubsub@main`](https://github.com/Azure/azure-webpubsub/tree/main/sdk/webpubsub-socketio-extension) (GitHub submodule) | [`1.2.1`](https://www.npmjs.com/package/@azure/web-pubsub-socket.io) (npm) |

The exact versions tested in each run are recorded in the release notes: [Dev SDK releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=dev-) · [Stable SDK releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=stable-).

## Releases

Each CI run publishes a **GitHub Release** containing pre-built test artifacts (`e2e-artifacts-{dev,stable}.tar.gz`). The archive includes the compiled test server, .NET / Java / Swift test binaries, the JavaScript WebPubSub chat client and Socket.IO extension harnesses (with `node_modules`), and `run-from-artifacts.sh` so tests can be re-run without rebuilding.

| Release | Description |
|---------|-------------|
| [`latest-dev`](https://github.com/Azure/azure-signalr-client-e2e/releases/tag/latest-dev) | Always points to the most recent Dev SDK run |
| [`latest-stable`](https://github.com/Azure/azure-signalr-client-e2e/releases/tag/latest-stable) | Always points to the most recent Stable SDK run |
| `dev-YYYYMMDD-HHMMSS` | Timestamped history for each Dev run |
| `stable-YYYYMMDD-HHMMSS` | Timestamped history for each Stable run |

Release notes record the exact SDK versions tested. Browse all: [Dev releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=dev-) · [Stable releases](https://github.com/Azure/azure-signalr-client-e2e/releases?q=stable-).


## Cloning with submodules

The .NET Server SDK and Swift client are Git submodules. The Web PubSub packages (chat client and Socket.IO extension) come from the `webpubsub/azure-webpubsub` submodule. Always clone the repository with submodules enabled:

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
- Node.js: >= 22 (JavaScript WebPubSub chat client and Socket.IO extension tests)

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

This compiles the test server, .NET / Java / Swift test binaries, and the JavaScript WebPubSub chat client and Socket.IO extension harnesses into `./artifacts/`.

The Socket.IO source build explicitly uses the SDK's `typescript` compiler rather than the shared `tsc` executable, which can also be supplied by `tsd`'s older compiler dependency.

By default the JavaScript WebPubSub chat client SDK is built from the `webpubsub` submodule (dev). To build against the published npm package instead, set `JAVASCRIPT_CHATCLIENT_SDK_SOURCE=npm` (optionally with `JAVASCRIPT_CHATCLIENT_SDK_VERSION=<version>`). The Socket.IO extension harness behaves the same way via `JAVASCRIPT_SOCKETIO_SDK_SOURCE=npm` (optionally with `JAVASCRIPT_SOCKETIO_SDK_VERSION=<version>`).

### 2. Run tests from artifacts

```bash
export E2E_SIGNALR_CONNECTION_STRING_DEFAULT="<your-azure-signalr-connection-string>"
# Optional — enables the JavaScript WebPubSub chat client suite:
export E2E_WEBPUBSUB_CHAT_CONNECTION_STRING="<your-azure-web-pubsub-connection-string>"
# Optional — enables the JavaScript WebPubSub Socket.IO extension suite (Web PubSub resource with an `eio_hub` hub):
export E2E_WEBPUBSUB_SOCKETIO_CONNECTION_STRING="<your-azure-web-pubsub-connection-string>"
./run-from-artifacts.sh
```

The script starts a local test server, runs all test suites (Java, Swift, .NET, JavaScript WebPubSub chat client, JavaScript WebPubSub Socket.IO extension), and exits with a non-zero code if any suite fails.

It always runs the .NET 8 E2E tests. If the artifact package includes `signalrservice/dotnet/net11.0/`, it also runs the .NET 11 Default Mode E2E tests. Install the matching .NET and ASP.NET Core runtimes for each included framework. Packages without .NET 11 artifacts remain supported; missing test DLLs or required runtimes cause a failure.

> **Note:** .NET tests do **not** use the local test server. They spin up an in-process Kestrel server that connects directly to Azure SignalR Service via `AddAzureSignalR()`. Java and Swift tests connect through the local test server. The JavaScript WebPubSub chat client tests target **Azure Web PubSub** through their own local negotiate server and are **skipped** when `E2E_WEBPUBSUB_CHAT_CONNECTION_STRING` is not set. The JavaScript WebPubSub Socket.IO extension tests reuse the SDK's own mocha suite against **Azure Web PubSub** (requires an `eio_hub` hub) and are **skipped** when `E2E_WEBPUBSUB_SOCKETIO_CONNECTION_STRING` is not set.

## CI Workflows

Three workflows run in sequence: **Sync Submodules** → **Client E2E (Dev SDK)** → **Client E2E (Stable SDK)**.

Triggered by every push to `master`, daily at 00:00 UTC, or manually.

- **Re-run a failed test**: Click a badge above → open the failed run → **Re-run failed jobs**.
- **Manually trigger**: Click a badge above → **Run workflow**.
