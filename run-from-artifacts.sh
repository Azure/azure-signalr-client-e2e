#!/usr/bin/env bash
###############################################################################
#  Run E2E tests from pre-built artifacts.                                   #
#                                                                            #
#  Usage:                                                                    #
#    ./run-from-artifacts.sh [ARTIFACT_DIR]                                  #
#                                                                            #
#  ARTIFACT_DIR defaults to ./artifacts (or the directory this script is in  #
#  if it was bundled inside the artifact package).                           #
#                                                                            #
#  Required env:                                                             #
#    E2E_SIGNALR_CONNECTION_STRING_DEFAULT          - Azure SignalR connection string         #
#                                     (.NET / Java / Swift suites)            #
#  Optional env:                                                             #
#    E2E_SIGNALR_CONNECTION_STRING_SERVERLESS - Serverless Management tests  #
#    E2E_WEBPUBSUB_CHAT_CONNECTION_STRING - Azure Web PubSub connection string      #
#                                     (JavaScript chat client suite; the      #
#                                      suite is skipped when unset)           #
#    E2E_WEBPUBSUB_SOCKETIO_CONNECTION_STRING - Azure Web PubSub connection    #
#                                     string (JavaScript Socket.IO extension   #
#                                      suite; skipped when unset. Requires a    #
#                                      hub named eio_hub on the resource)       #
#                                                                            #
#  Runtimes required on the machine consuming the artifact:                  #
#    .NET 8 runtime, JDK 21 + Maven, Swift toolchain, Node.js 22+, curl.     #
#    Matching .NET and ASP.NET Core runtimes for net8.0 and, when included,  #
#    net11.0 test artifacts.                                                 #
#                                                                            #
#  Expected artifact layout:                                                 #
#    <ARTIFACT_DIR>/                                                         #
#      signalrservice/server/              - published .NET test-server       #
#      signalrservice/dotnet/net8.0/       - built .NET E2E test DLLs         #
#      signalrservice/dotnet/net11.0/      - optional .NET 11 E2E test DLLs   #
#      signalrservice/java/target/         - compiled Java test classes       #
#      signalrservice/java/pom.xml         - Maven POM for surefire runner    #
#      signalrservice/swift/.build/        - built Swift test binaries        #
#      webpubsub/javascript/chatclient/    - WebPubSub chat client harness     #
#      webpubsub/javascript/socketio/      - WebPubSub Socket.IO ext harness    #
###############################################################################
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If the script lives inside the artifact dir (bundled), use SCRIPT_DIR as default.
# Otherwise fall back to ./artifacts.
if [[ -d "$SCRIPT_DIR/signalrservice/server" ]]; then
  DEFAULT_DIR="$SCRIPT_DIR"
else
  DEFAULT_DIR="$SCRIPT_DIR/artifacts"
fi
ARTIFACT_DIR="${1:-$DEFAULT_DIR}"

export SIGNALR_INTEGRATION_TEST_URL="http://localhost:8080/test"

# ── Color helpers ────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
else
  BLUE=''; GREEN=''; RED=''; NC=''
fi
log()  { echo -e "${BLUE}[RUN]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# ── Validate ─────────────────────────────────────────────────────────────────
if [[ -z "${E2E_SIGNALR_CONNECTION_STRING_DEFAULT:-}" ]]; then
  fail "E2E_SIGNALR_CONNECTION_STRING_DEFAULT is not set."
  exit 1
fi

if [[ ! -d "$ARTIFACT_DIR/signalrservice/server" ]]; then
  fail "Artifact directory not found or missing signalrservice/server/: $ARTIFACT_DIR"
  exit 1
fi

# ── Print configuration ─────────────────────────────────────────────────────
echo "==> Configuration:"
echo "  ARTIFACT_DIR:  $ARTIFACT_DIR"
echo "  TEST_URL:      $SIGNALR_INTEGRATION_TEST_URL"
echo "  CONN_STRING:   ${E2E_SIGNALR_CONNECTION_STRING_DEFAULT:0:20}...${E2E_SIGNALR_CONNECTION_STRING_DEFAULT: -20}"
echo ""

# ── Start test-server from published artifact ────────────────────────────────
log "Starting test-server from artifact..."
export Azure__SignalR__ConnectionString="${E2E_SIGNALR_CONNECTION_STRING_DEFAULT}"
export ASPNETCORE_URLS="http://localhost:8080"
SERVER_APP_NAME="${ASRS_APP_NAME-}"
if [[ -n "${E2E_SIGNALR_CONNECTION_STRING_SERVERLESS:-}" ]]; then
  SERVER_APP_NAME=""
fi
ASRS_APP_NAME="$SERVER_APP_NAME" "$ARTIFACT_DIR/signalrservice/server/IntegrationTestServer" > "$ARTIFACT_DIR/signalrservice/server/test-server.log" 2>&1 &
SERVER_PID=$!

# Wait for server to be ready (SignalR hub returns 400 on plain GET, so we check for any HTTP response)
for i in {1..30}; do
  HTTP_CODE=$(curl -sf -o /dev/null -w '%{http_code}' "$SIGNALR_INTEGRATION_TEST_URL" 2>/dev/null || true)
  if [[ -n "$HTTP_CODE" && "$HTTP_CODE" != "000" ]]; then
    ok "test-server is ready (PID $SERVER_PID, HTTP $HTTP_CODE)"
    break
  fi
  if ! kill -0 $SERVER_PID 2>/dev/null; then
    fail "test-server exited unexpectedly. Log:"
    cat "$ARTIFACT_DIR/signalrservice/server/test-server.log" >&2
    exit 1
  fi
  sleep 1
done

HTTP_CODE=$(curl -sf -o /dev/null -w '%{http_code}' "$SIGNALR_INTEGRATION_TEST_URL" 2>/dev/null || true)
if [[ -z "$HTTP_CODE" || "$HTTP_CODE" == "000" ]]; then
  fail "test-server did not start within 30 seconds. Log:"
  cat "$ARTIFACT_DIR/signalrservice/server/test-server.log" >&2
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi

# ── Cleanup handler ──────────────────────────────────────────────────────────
cleanup() {
  if [[ -n "${APP_SERVER_PID:-}" ]]; then
    log "Stopping Management app server (PID $APP_SERVER_PID)..."
    kill "$APP_SERVER_PID" 2>/dev/null || true
    wait "$APP_SERVER_PID" 2>/dev/null || true
  fi
  log "Stopping test-server (PID $SERVER_PID)..."
  kill $SERVER_PID 2>/dev/null || true
  wait $SERVER_PID 2>/dev/null || true
}
trap cleanup EXIT

failures=0

# ── Java tests (from pre-built target/) ──────────────────────────────────────
if [[ -d "$ARTIFACT_DIR/signalrservice/java/target" ]]; then
  log "Running Java tests..."
  (
    cd "$ARTIFACT_DIR/signalrservice/java"
    mvn surefire:test -Dtest=IntegrationTests
  )
  java_status=$?
  if [[ $java_status -ne 0 ]]; then
    fail "Java tests failed (exit $java_status)"
    failures=1
  else
    ok "Java tests passed"
  fi
else
  fail "Java artifacts not found, skipping"
  failures=1
fi

# ── Swift tests (from pre-built .build/) ─────────────────────────────────────
SWIFT_XCTEST=$(find "$ARTIFACT_DIR/signalrservice/swift/.build" -name '*.xctest' -type f 2>/dev/null | head -1)
if [[ -n "$SWIFT_XCTEST" ]]; then
  log "Running Swift tests..."
  chmod +x "$SWIFT_XCTEST"
  "$SWIFT_XCTEST" SignalRClientIntegrationTests
  swift_status=$?
  if [[ $swift_status -ne 0 ]]; then
    fail "Swift tests failed (exit $swift_status)"
    failures=1
  else
    ok "Swift tests passed"
  fi
else
  fail "Swift test binary not found, skipping"
  failures=1
fi

# ── .NET tests (from pre-built DLLs) ────────────────────────────────────────
export Azure__SignalR__ConnectionString="${E2E_SIGNALR_CONNECTION_STRING_DEFAULT}"

run_dotnet_tests() {
  local label="$1" dll="$2" filter="${3:-}"
  local command=(dotnet vstest "$dll" --logger:"console;verbosity=normal")
  if [[ -n "$filter" ]]; then
    command+=(--testcasefilter:"$filter")
  fi
  log "Running .NET tests ($label)..."
  if "${command[@]}"; then
    ok ".NET tests ($label) passed"
  else
    fail ".NET tests ($label) failed"
    failures=1
  fi
}

if [[ -n "${E2E_SIGNALR_CONNECTION_STRING_SERVERLESS:-}" &&
      -f "$ARTIFACT_DIR/signalrservice/dotnet/net8.0/Microsoft.Azure.SignalR.E2ETests.dll" ]]; then
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/management-test 2>/dev/null || true)
  if [[ -z "$HTTP_CODE" || "$HTTP_CODE" == "000" || "$HTTP_CODE" == "404" ]]; then
    fail "Artifact test server is missing the Management hub required for Serverless test splitting."
    exit 1
  fi
  log "Starting Management app server for the appName namespace..."
  ASRS_APP_NAME=appName ASPNETCORE_URLS=http://localhost:8082 \
    "$ARTIFACT_DIR/signalrservice/server/IntegrationTestServer" > "$ARTIFACT_DIR/signalrservice/server/management-app-server.log" 2>&1 &
  APP_SERVER_PID=$!
  for i in {1..30}; do
    if ! kill -0 "$APP_SERVER_PID" 2>/dev/null; then
      fail "Management app server exited unexpectedly."
      cat "$ARTIFACT_DIR/signalrservice/server/management-app-server.log" >&2
      exit 1
    fi
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8082/management-test 2>/dev/null || true)
    if [[ -n "$HTTP_CODE" && "$HTTP_CODE" != "000" && "$HTTP_CODE" != "404" ]]; then
      break
    fi
    sleep 1
  done
  if [[ -z "$HTTP_CODE" || "$HTTP_CODE" == "000" || "$HTTP_CODE" == "404" ]]; then
    fail "Management app server did not expose the Management hub within 30 seconds."
    cat "$ARTIFACT_DIR/signalrservice/server/management-app-server.log" >&2
    exit 1
  fi
fi

for FRAMEWORK in net8.0 net11.0; do
  if [[ "$FRAMEWORK" == "net11.0" && ! -d "$ARTIFACT_DIR/signalrservice/dotnet/$FRAMEWORK" ]]; then
    log ".NET 11 artifacts not included; running .NET 8 only."
    continue
  fi

  DOTNET_DLL="$ARTIFACT_DIR/signalrservice/dotnet/$FRAMEWORK/Microsoft.Azure.SignalR.E2ETests.dll"
  if [[ ! -f "$DOTNET_DLL" ]]; then
    fail ".NET test DLL not found: $DOTNET_DLL"
    failures=1
    continue
  fi

  if [[ "$FRAMEWORK" == "net11.0" ]]; then
    run_dotnet_tests "$FRAMEWORK Default Mode" "$DOTNET_DLL" 'FullyQualifiedName!~Management'
  elif [[ -n "${E2E_SIGNALR_CONNECTION_STRING_SERVERLESS:-}" ]]; then
    run_dotnet_tests "$FRAMEWORK Default Mode" "$DOTNET_DLL" 'FullyQualifiedName!~Management'
    run_dotnet_tests "$FRAMEWORK Management Default Mode" "$DOTNET_DLL" \
      'FullyQualifiedName~Management&(FullyQualifiedName~ServiceHubContextE2EFacts.ClientInvocation_|FullyQualifiedName~ServiceHubContextE2EFacts.CloseConnectionTest)'
    export Azure__SignalR__ConnectionString="${E2E_SIGNALR_CONNECTION_STRING_SERVERLESS}"
    run_dotnet_tests "$FRAMEWORK Serverless Mode" "$DOTNET_DLL" \
      'FullyQualifiedName~Management&FullyQualifiedName!~ServiceHubContextE2EFacts.ClientInvocation_&FullyQualifiedName!~ServiceHubContextE2EFacts.CloseConnectionTest'
    export Azure__SignalR__ConnectionString="${E2E_SIGNALR_CONNECTION_STRING_DEFAULT}"
  else
    log "Serverless connection string not set; running all .NET 8 tests against Default Mode."
    run_dotnet_tests "$FRAMEWORK Default Mode" "$DOTNET_DLL"
  fi
done

# ── JavaScript — WebPubSub chat client tests (from pre-built harness) ────────
if [[ -d "$ARTIFACT_DIR/webpubsub/javascript/chatclient" ]]; then
  if [[ -z "${E2E_WEBPUBSUB_CHAT_CONNECTION_STRING:-}" ]]; then
    log "E2E_WEBPUBSUB_CHAT_CONNECTION_STRING not set — skipping JavaScript WebPubSub chat client tests"
  else
    log "Running JavaScript WebPubSub chat client tests..."
    (
      cd "$ARTIFACT_DIR/webpubsub/javascript/chatclient"
      export E2E_WEBPUBSUB_CHAT_CONNECTION_STRING="${E2E_WEBPUBSUB_CHAT_CONNECTION_STRING}"
      # node_modules are bundled in the artifact; reinstall only if missing
      # (e.g. it was stripped in transit). package.json pins a valid npm version.
      if [[ ! -d node_modules ]]; then
        log "node_modules missing — installing dependencies..."
        npm install --no-audit --no-fund
      fi
      node server.mjs > chat-server.log 2>&1 &
      CHAT_PID=$!
      for i in {1..30}; do
        curl -sf -o /dev/null "http://localhost:3000/negotiate?userId=probe" && break
        sleep 1
      done
      if [[ -f ./run-tests.sh ]]; then
        bash ./run-tests.sh
      else
        log "Older Chat Client artifact has no selective retry runner; using npm test."
        npm test
      fi
      status=$?
      kill $CHAT_PID 2>/dev/null || true
      exit $status
    )
    chat_status=$?
    if [[ $chat_status -ne 0 ]]; then
      fail "JavaScript WebPubSub chat client tests failed (exit $chat_status)"
      failures=1
    else
      ok "JavaScript WebPubSub chat client tests passed"
    fi
  fi
else
  fail "JavaScript WebPubSub chat client artifacts not found, skipping"
  failures=1
fi

# ── JavaScript — WebPubSub Socket.IO extension tests (from pre-built harness) ─
if [[ -d "$ARTIFACT_DIR/webpubsub/javascript/socketio" ]]; then
  if [[ -z "${E2E_WEBPUBSUB_SOCKETIO_CONNECTION_STRING:-}" ]]; then
    log "E2E_WEBPUBSUB_SOCKETIO_CONNECTION_STRING not set — skipping JavaScript WebPubSub Socket.IO extension tests"
  else
    log "Running JavaScript WebPubSub Socket.IO extension tests..."
    (
      cd "$ARTIFACT_DIR/webpubsub/javascript/socketio"
      export WebPubSubConnectionString="${E2E_WEBPUBSUB_SOCKETIO_CONNECTION_STRING}"
      export WebPubSubHub="${WEBPUBSUB_SOCKETIO_HUB:-eio_hub}"
      export SocketIoPort="${SOCKETIO_PORT:-3000}"
      # node_modules are bundled in the artifact; reinstall only if missing.
      if [[ ! -d node_modules ]]; then
        log "node_modules missing — installing dependencies..."
        npm install --no-audit --no-fund
      fi
      npm test
    )
    socketio_status=$?
    if [[ $socketio_status -ne 0 ]]; then
      fail "JavaScript WebPubSub Socket.IO extension tests failed (exit $socketio_status)"
      failures=1
    else
      ok "JavaScript WebPubSub Socket.IO extension tests passed"
    fi
  fi
else
  fail "JavaScript WebPubSub Socket.IO extension artifacts not found, skipping"
  failures=1
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [[ $failures -ne 0 ]]; then
  fail "Summary: at least one test suite failed. See logs above."
  exit 1
fi

ok "Summary: all test suites passed."
exit 0
