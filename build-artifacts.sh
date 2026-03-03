#!/usr/bin/env bash
###############################################################################
#  Build all client E2E test artifacts (server, .NET, Java, Swift).          #
#                                                                            #
#  Usage:                                                                    #
#    ./build-artifacts.sh [OUTPUT_DIR]                                       #
#                                                                            #
#  OUTPUT_DIR defaults to ./artifacts if not supplied.                        #
#  Prerequisites: .NET 8 SDK, JDK 21 + Maven, Swift toolchain.              #
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
  "$REPO_ROOT/server/IntegrationTestServer.csproj" \
  -c Release \
  -o "$OUTPUT_DIR/server" \
  -p:DefineConstants="USE_AZURE_SIGNALR"
ok "test-server → $OUTPUT_DIR/server/"

# ── .NET: build E2E tests from SDK submodule ─────────────────────────────────
log "Building .NET E2E tests..."
dotnet build \
  "$REPO_ROOT/dotnet/test/Microsoft.Azure.SignalR.E2ETests/Microsoft.Azure.SignalR.E2ETests.csproj" \
  -c Release
mkdir -p "$OUTPUT_DIR/dotnet"
cp -r "$REPO_ROOT/dotnet/test/Microsoft.Azure.SignalR.E2ETests/bin/Release/." \
  "$OUTPUT_DIR/dotnet/"
ok ".NET E2E tests → $OUTPUT_DIR/dotnet/"

# ── Java: build + package test classes ───────────────────────────────────────
log "Building Java tests..."
(
  cd "$REPO_ROOT/java"
  mvn package -DskipTests -q
)
mkdir -p "$OUTPUT_DIR/java"
cp -r "$REPO_ROOT/java/target/" "$OUTPUT_DIR/java/"
cp    "$REPO_ROOT/java/pom.xml" "$OUTPUT_DIR/java/"
ok "Java tests → $OUTPUT_DIR/java/"

# ── Swift: build tests ──────────────────────────────────────────────────────
log "Building Swift tests..."
(
  cd "$REPO_ROOT/swift"
  swift build --build-tests
)
mkdir -p "$OUTPUT_DIR/swift"
cp -r "$REPO_ROOT/swift/.build/" "$OUTPUT_DIR/swift/.build"
ok "Swift tests → $OUTPUT_DIR/swift/"

# ── Copy run script into artifact package ────────────────────────────────────
log "Bundling run-from-artifacts.sh..."
cp "$REPO_ROOT/run-from-artifacts.sh" "$OUTPUT_DIR/"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
log "Artifact summary:"
find "$OUTPUT_DIR" -maxdepth 2 -type f | head -40
echo ""
ok "All artifacts built successfully → $OUTPUT_DIR"
