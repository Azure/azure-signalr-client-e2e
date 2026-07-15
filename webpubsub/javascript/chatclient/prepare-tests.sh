#!/usr/bin/env bash
###############################################################################
#  Prepare the chat client E2E tests.                                         #
#                                                                             #
#  The integration tests are owned by the chat client SDK itself, in the      #
#  webpubsub submodule (sdk/webpubsub-chat-client/tests). We copy them here    #
#  verbatim and only rewrite the SDK import specifier from the SDK's internal  #
#  relative source path to the published package name, so the exact same test  #
#  logic runs against either the source-packed (dev) or npm (stable) SDK.      #
#                                                                             #
#  Usage:                                                                      #
#    ./prepare-tests.sh [SDK_TESTS_DIR]                                        #
#  SDK_TESTS_DIR defaults to ../../azure-webpubsub/sdk/webpubsub-chat-client/tests #
###############################################################################
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_TESTS="${1:-${HARNESS_DIR}/../../azure-webpubsub/sdk/webpubsub-chat-client/tests}"

if [[ ! -d "$SDK_TESTS" ]]; then
  echo "ERROR: chat client SDK tests not found at: $SDK_TESTS" >&2
  echo "       Did you initialize the 'webpubsub' submodule? (git submodule update --init --recursive)" >&2
  exit 1
fi

mkdir -p "$HARNESS_DIR/tests"

# Only the SDK's E2E/integration suite (its `test:integration` target) plus its
# shared helpers. Imports of the SDK source are rewritten to the package name.
for f in integration.test.ts testUtils.ts; do
  sed -e 's#\.\./src/chatClient\.js#@azure/web-pubsub-chat-client#g' \
      -e 's#\.\./src/generatedTypes\.js#@azure/web-pubsub-chat-client#g' \
      -e 's#\.\./src/models\.js#@azure/web-pubsub-chat-client#g' \
      -e 's#\.\./src/events\.js#@azure/web-pubsub-chat-client#g' \
      "$SDK_TESTS/$f" > "$HARNESS_DIR/tests/$f"
  echo "  prepared tests/$f (imports rewritten to @azure/web-pubsub-chat-client)"
done
