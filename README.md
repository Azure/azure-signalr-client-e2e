# Azure SignalR Client E2E Tests

This repository hosts multiple languages client E2E tests for Azure SignalR. It helps verify all language clients work correctly with Azure SignalR Service in a single pass.

- Supported clients: [Java](https://github.com/dotnet/aspnetcore/tree/main/src/SignalR/clients/java/signalr), [Swift](https://github.com/dotnet/signalr-client-swift/)
- Unsupported clients (in-progress): [C++](https://github.com/aspnet/SignalR-Client-Cpp), [C#](https://github.com/dotnet/aspnetcore/tree/main/src/SignalR/clients/csharp)

## Cloning with submodules

The Swift client is included as a Git submodule. Always clone the repository with submodules enabled:

```bash
git clone --recurse-submodules https://github.com/Azure/azure-signalr-client-e2e.git
```

If you already cloned without submodules, run:

```bash
git submodule update --init --recursive
```

## Install Prerequisites
### Requirements
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
- Run a local test server at `http://localhost:8080/test`
- Runs the Java tests with Maven surefire selection (`mvn -Dtest=IntegrationTests test` in `java/`)
- Runs the Swift tests with filter (`swift test --filter SignalRClientIntegrationTests` in `swift/`)
    - Known issue: even if a failure occurs, it still continues to run all tests
- Emits a non-zero exit code when any suite fails