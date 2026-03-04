# Azure SignalR Client E2E Tests

[![Build & Release](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/build.yml/badge.svg)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/build.yml)
[![.NET E2E (Default)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-dotnet-default.yml/badge.svg)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-dotnet-default.yml)
[![.NET E2E (Serverless)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-dotnet-serverless.yml/badge.svg)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-dotnet-serverless.yml)
[![Java E2E](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-java.yml/badge.svg)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-java.yml)
[![Swift Linux E2E](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-swift-linux.yml/badge.svg)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-swift-linux.yml)
[![Swift macOS E2E](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-swift-macos.yml/badge.svg)](https://github.com/Azure/azure-signalr-client-e2e/actions/workflows/test-swift-macos.yml)

This repository hosts multiple languages client E2E tests for Azure SignalR. It helps verify all language clients work correctly with Azure SignalR Service in a single pass.

- Supported clients: [Java](https://github.com/dotnet/aspnetcore/tree/main/src/SignalR/clients/java/signalr), [Swift](https://github.com/dotnet/signalr-client-swift/), [.NET](https://github.com/Azure/azure-signalr)

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