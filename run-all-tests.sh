#!/usr/bin/env bash
set -uo pipefail

# set test 
JAVA_TEST_CMD=(mvn -Dtest=IntegrationTests test)
SWIFT_TEST_CMD=(swift test --filter SignalRClientIntegrationTests)
DOTNET_TEST_CMD=(dotnet test --logger:"console;verbosity=normal")
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SIGNALR_INTEGRATION_TEST_URL="http://localhost:8080/test"

# Check E2E_SIGNALR_CONNECTION_STRING_DEFAULT
if [ -z "$E2E_SIGNALR_CONNECTION_STRING_DEFAULT" ]; then
    # Print an error message to standard error (stderr)
    echo "❌ ERROR: The E2E_SIGNALR_CONNECTION_STRING_DEFAULT environment variable is not set or is empty." >&2
    # Exit with a non-zero status code (indicating failure)
    exit 1
fi

# Print Configuration
echo "==> Test Configuration:"
echo "SIGNALR_INTEGRATION_TEST_URL=${SIGNALR_INTEGRATION_TEST_URL}"
echo "JAVA_TEST_CMD: ${JAVA_TEST_CMD[*]}"
echo "SWIFT_TEST_CMD: ${SWIFT_TEST_CMD[*]}"
echo "DOTNET_TEST_CMD: ${DOTNET_TEST_CMD[*]}"
echo "E2E_SIGNALR_CONNECTION_STRING_DEFAULT=\"${E2E_SIGNALR_CONNECTION_STRING_DEFAULT:0:20}...${E2E_SIGNALR_CONNECTION_STRING_DEFAULT: -20}\""

# Run Server
echo "==> Running Test Server..."
(
  cd "$REPO_ROOT/signalrservice/server"
  export Azure__SignalR__ConnectionString="${E2E_SIGNALR_CONNECTION_STRING_DEFAULT}"
  dotnet run -p:DefineConstants="USE_AZURE_SIGNALR" > test-server.log 2>&1 &
  sleep 5
)

failures=0

# Run different language tests
echo "==> Running Java tests..."
(
  cd "$REPO_ROOT/signalrservice/java"
  "${JAVA_TEST_CMD[@]}"
)
java_status=$?
if [[ $java_status -ne 0 ]]; then
  echo "Java tests failed with exit code ${java_status}"
  failures=1
else
  echo "Java tests passed"
fi


echo "==> Running Swift tests..."
(
  cd "$REPO_ROOT/signalrservice/swift"
  "${SWIFT_TEST_CMD[@]}"
)
swift_status=$?
if [[ $swift_status -ne 0 ]]; then
  echo "Swift tests failed with exit code ${swift_status}"
  failures=1
else
  echo "Swift tests passed"
fi

echo "==> Running .NET tests..."
(
  cd "$REPO_ROOT/signalrservice/dotnet/test/Microsoft.Azure.SignalR.E2ETests"
  export Azure__SignalR__ConnectionString="${E2E_SIGNALR_CONNECTION_STRING_DEFAULT}"
  "${DOTNET_TEST_CMD[@]}"
)
dotnet_status=$?
if [[ $dotnet_status -ne 0 ]]; then
  echo ".NET tests failed with exit code ${dotnet_status}"
  failures=1
else
  echo ".NET tests passed"
fi

echo "==> Running JavaScript WebPubSub chat client tests..."
if [ -z "${E2E_WEBPUBSUB_CHAT_CONNECTION_STRING:-}" ]; then
  echo "⚠️  E2E_WEBPUBSUB_CHAT_CONNECTION_STRING not set — skipping JavaScript WebPubSub chat client tests"
else
  (
    cd "$REPO_ROOT/webpubsub/javascript/chatclient"
    export E2E_WEBPUBSUB_CHAT_CONNECTION_STRING="${E2E_WEBPUBSUB_CHAT_CONNECTION_STRING}"
    bash prepare-tests.sh
    npm install --no-audit --no-fund
    node server.mjs > chat-server.log 2>&1 &
    CHAT_PID=$!
    # Wait for the negotiate server to be ready
    for i in $(seq 1 30); do
      curl -sf -o /dev/null "http://localhost:3000/negotiate?userId=probe" && break
      sleep 1
    done
    npm test
    status=$?
    kill $CHAT_PID 2>/dev/null || true
    exit $status
  )
  chat_status=$?
  if [[ $chat_status -ne 0 ]]; then
    echo "JavaScript WebPubSub chat client tests failed with exit code ${chat_status}"
    failures=1
  else
    echo "JavaScript WebPubSub chat client tests passed"
  fi
fi

if [[ $failures -ne 0 ]]; then
  echo "==> Summary: at least one test suite failed. See logs above."
  exit -1
fi

echo "==> Summary: all test suites passed."
exit 0