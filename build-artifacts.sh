#!/usr/bin/env bash
###############################################################################
#  Build all client E2E test artifacts                                       #
#  (server, .NET, Java, Swift, JavaScript WebPubSub chat client).            #
#                                                                            #
#  Usage:                                                                    #
#    ./build-artifacts.sh [OUTPUT_DIR]                                       #
#                                                                            #
#  OUTPUT_DIR defaults to ./artifacts if not supplied.                        #
#  Prerequisites: .NET 8 SDK, JDK 21 + Maven, Swift toolchain, Node.js 20+.  #
###############################################################################
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${REPO_ROOT}/artifacts}"

mkdir -p "$OUTPUT_DIR"

# ── Color helpers ────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
else
  BLUE=''; GREEN=''; RED=''; NC=''
fi
log()  { echo -e "${BLUE}[BUILD]${NC} $*"; }
ok()   { echo -e "${GREEN}[  OK ]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# ── .NET: publish test-server ────────────────────────────────────────────────
log "Publishing test-server..."
dotnet publish \
  "$REPO_ROOT/signalrservice/server/IntegrationTestServer.csproj" \
  -c Release \
  -o "$OUTPUT_DIR/signalrservice/server" \
  -p:DefineConstants="USE_AZURE_SIGNALR"
ok "test-server → $OUTPUT_DIR/signalrservice/server/"

# ── .NET: build E2E tests from SDK submodule ─────────────────────────────────
log "Building .NET E2E tests..."
# Patch: inject unique AppName per test to isolate hub namespaces in Azure SignalR Service
sed -i 's/await server\.StartAsync()/await server.StartAsync(new Dictionary<string, string> { { "AppName", $"e2e_{System.Guid.NewGuid():N}" } })/' \
  "$REPO_ROOT/signalrservice/dotnet/test/Microsoft.Azure.SignalR.Tests.Common/E2ETest/ServiceE2EFactsBase.cs"
log "Patched ServiceE2EFactsBase.cs with unique AppName per test"
dotnet build \
  "$REPO_ROOT/signalrservice/dotnet/test/Microsoft.Azure.SignalR.E2ETests/Microsoft.Azure.SignalR.E2ETests.csproj" \
  -c Release
mkdir -p "$OUTPUT_DIR/signalrservice/dotnet"
cp -r "$REPO_ROOT/signalrservice/dotnet/test/Microsoft.Azure.SignalR.E2ETests/bin/Release/." \
  "$OUTPUT_DIR/signalrservice/dotnet/"
ok ".NET E2E tests → $OUTPUT_DIR/signalrservice/dotnet/"

# ── Java: build + package test classes ───────────────────────────────────────
log "Building Java tests..."
(
  cd "$REPO_ROOT/signalrservice/java"
  mvn package -DskipTests -q
  # Copy all runtime + test dependencies into target/dependency/
  # so tests can run offline with just `java -cp`
  mvn dependency:copy-dependencies -DincludeScope=test -q
)
mkdir -p "$OUTPUT_DIR/signalrservice/java"
cp -r "$REPO_ROOT/signalrservice/java/target/" "$OUTPUT_DIR/signalrservice/java/"
cp    "$REPO_ROOT/signalrservice/java/pom.xml" "$OUTPUT_DIR/signalrservice/java/"
ok "Java tests → $OUTPUT_DIR/signalrservice/java/"

# ── Swift: build tests ────────────────────────────────────────────────────────
# Swift compiles on both macOS and Linux. On Linux, only longPolling transport
# is supported (WebSocket/SSE require URLSession APIs not yet available in
# swift-corelibs-foundation).
log "Building Swift tests..."
(
  cd "$REPO_ROOT/signalrservice/swift"
  swift build --build-tests
)
mkdir -p "$OUTPUT_DIR/signalrservice/swift"
cp -r "$REPO_ROOT/signalrservice/swift/.build/" "$OUTPUT_DIR/signalrservice/swift/.build"
# Also bundle source for cross-distro builds (ADO builds from source on Azure Linux)
cp "$REPO_ROOT/signalrservice/swift/Package.swift" "$OUTPUT_DIR/signalrservice/swift/"
cp -r "$REPO_ROOT/signalrservice/swift/Sources" "$OUTPUT_DIR/signalrservice/swift/Sources"
cp -r "$REPO_ROOT/signalrservice/swift/Tests" "$OUTPUT_DIR/signalrservice/swift/Tests"
ok "Swift tests → $OUTPUT_DIR/signalrservice/swift/"

# ── JavaScript — WebPubSub chat client: build test harness ───────────────────
# The JavaScript WebPubSub chat client is a TypeScript SDK run with `tsx --test`.
# Its version source is selected via JAVASCRIPT_CHATCLIENT_SDK_SOURCE:
#   submodule (default) → build @azure/web-pubsub-chat-client from the webpubsub
#                         submodule (dev), npm pack it, and install into harness.
#   npm                 → install the published package from npm (stable),
#                         optionally pinned to JAVASCRIPT_CHATCLIENT_SDK_VERSION.
log "Building JavaScript WebPubSub chat client tests..."
JAVASCRIPT_CHATCLIENT_SDK_SOURCE="${JAVASCRIPT_CHATCLIENT_SDK_SOURCE:-submodule}"
(
  cd "$REPO_ROOT/webpubsub/javascript/chatclient"
  npm install
  if [[ "$JAVASCRIPT_CHATCLIENT_SDK_SOURCE" == "submodule" ]]; then
    SDK_DIR="$REPO_ROOT/webpubsub/azure-webpubsub/sdk/webpubsub-chat-client"
    log "  JavaScript WebPubSub chat client SDK: building from webpubsub submodule (dev) → $SDK_DIR"
    (
      cd "$SDK_DIR"
      npm install
      npm run build
    )
    TARBALL=$(cd "$SDK_DIR" && npm pack | tail -1)
    log "  JavaScript WebPubSub chat client SDK: installing packed tarball $TARBALL"
    # --no-save: install the dev build into node_modules without writing an
    # absolute build-machine path into package.json (which would break a later
    # `npm install` on the machine that consumes the artifact). node_modules is
    # bundled into the artifact and is the source of truth for running the tests.
    npm install "$SDK_DIR/$TARBALL" --no-save --no-audit --no-fund
  else
    JAVASCRIPT_CHATCLIENT_SDK_VERSION="${JAVASCRIPT_CHATCLIENT_SDK_VERSION:-}"
    if [[ -n "$JAVASCRIPT_CHATCLIENT_SDK_VERSION" ]]; then
      log "  JavaScript WebPubSub chat client SDK: installing @azure/web-pubsub-chat-client@${JAVASCRIPT_CHATCLIENT_SDK_VERSION} from npm (stable)"
      npm install "@azure/web-pubsub-chat-client@${JAVASCRIPT_CHATCLIENT_SDK_VERSION}"
    else
      log "  JavaScript WebPubSub chat client SDK: using version pinned in webpubsub/javascript/chatclient/package.json (stable)"
    fi
  fi
)
# Copy the SDK's own integration tests from the submodule (single source of
# truth) and rewrite their SDK imports to the package name.
log "  preparing JavaScript WebPubSub chat client tests from submodule..."
bash "$REPO_ROOT/webpubsub/javascript/chatclient/prepare-tests.sh"
mkdir -p "$OUTPUT_DIR/webpubsub/javascript/chatclient"
# Copy the harness (including installed node_modules and prepared tests) so
# tests run offline from the artifact package.
cp -r "$REPO_ROOT/webpubsub/javascript/chatclient/." "$OUTPUT_DIR/webpubsub/javascript/chatclient/"
ok "JavaScript WebPubSub chat client tests → $OUTPUT_DIR/webpubsub/javascript/chatclient/"

# ── Copy run script into artifact package ────────────────────────────────────
log "Bundling run-from-artifacts.sh..."
cp "$REPO_ROOT/run-from-artifacts.sh" "$OUTPUT_DIR/"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
log "Artifact summary:"
find "$OUTPUT_DIR" -maxdepth 2 -type f | head -40
echo ""
ok "All artifacts built successfully → $OUTPUT_DIR"
