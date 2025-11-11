#!/usr/bin/env bash
set -uo pipefail

# set test 
JAVA_TEST_CMD=(mvn -Dtest=IntegrationTests test)
SWIFT_TEST_CMD=(swift test --filter SignalRClientIntegrationTests)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SIGNALR_INTEGRATION_TEST_URL="http://localhost:8080/test"

# Check E2E_CONNECTION_STRING
if [ -z "$E2E_CONNECTION_STRING" ]; then
    # Print an error message to standard error (stderr)
    echo "❌ ERROR: The E2E_CONNECTION_STRING environment variable is not set or is empty." >&2
    # Exit with a non-zero status code (indicating failure)
    exit 1
fi

# Print Configuration
echo "==> Test Configuration:"
echo "SIGNALR_INTEGRATION_TEST_URL=${SIGNALR_INTEGRATION_TEST_URL}"
echo "JAVA_TEST_CMD: ${JAVA_TEST_CMD[*]}"
echo "SWIFT_TEST_CMD: ${SWIFT_TEST_CMD[*]}"
echo "E2E_CONNECTION_STRING=\"${E2E_CONNECTION_STRING:0:20}...${E2E_CONNECTION_STRING: -20}\""

# Run Server
echo "==> Running Test Server..."
(
  cd "$REPO_ROOT/test-server"
  export Azure__SignalR__ConnectionString="${E2E_CONNECTION_STRING}"
  dotnet run -p:DefineConstants="USE_AZURE_SIGNALR" > test-server.log 2>&1 &
  sleep 5
)

failures=0

# Run different language tests
echo "==> Running Java tests..."
(
  cd "$REPO_ROOT/java"
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
  cd "$REPO_ROOT/swift"
  "${SWIFT_TEST_CMD[@]}"
)
swift_status=$?
if [[ $swift_status -ne 0 ]]; then
  echo "Swift tests failed with exit code ${swift_status}"
  failures=1
else
  echo "Swift tests passed"
fi

if [[ $failures -ne 0 ]]; then
  echo "==> Summary: at least one test suite failed. See logs above."
  exit -1
fi

echo "==> Summary: all test suites passed."
exit 0