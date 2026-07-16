#!/usr/bin/env bash
###############################################################################
#  Prepare the Socket.IO extension E2E tests.                                 #
#                                                                             #
#  The test suite is owned by the Socket.IO extension SDK itself, in the      #
#  webpubsub submodule (sdk/webpubsub-socketio-extension/test). It is the      #
#  exact suite run by the SDK's own "Socket.IO E2E test" pipeline             #
#  (.github/workflows/socketio_e2e.yml in Azure/azure-webpubsub): a real      #
#  Socket.IO server backed by Azure Web PubSub, exercised by real            #
#  socket.io-clients through the service.                                      #
#                                                                             #
#  We copy the suite here verbatim and only rewrite the imports that reach    #
#  into the SDK's internal source tree so the same tests run against either   #
#  the source-packed (dev) or npm (stable) SDK:                               #
#    - `../src`               -> @azure/web-pubsub-socket.io  (public entry)   #
#    - `../src/common/utils`  -> public `NegotiateOptions` + an inline `debug` #
#                                wrapper for `debugModule` (the only symbol    #
#                                not part of the package's public surface).    #
#                                                                             #
#  Usage:                                                                      #
#    ./prepare-tests.sh [SDK_TESTS_DIR]                                        #
#  SDK_TESTS_DIR defaults to                                                   #
#    ../../azure-webpubsub/sdk/webpubsub-socketio-extension/test               #
###############################################################################
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_TESTS="${1:-${HARNESS_DIR}/../../azure-webpubsub/sdk/webpubsub-socketio-extension/test}"

if [[ ! -d "$SDK_TESTS" ]]; then
  echo "ERROR: Socket.IO extension tests not found at: $SDK_TESTS" >&2
  echo "       Did you initialize the 'webpubsub' submodule? (git submodule update --init --recursive)" >&2
  exit 1
fi

rm -rf "$HARNESS_DIR/tests"
mkdir -p "$HARNESS_DIR/tests"
# Copy the whole suite verbatim (SIO/, web-pubsub/, support/, index.ts, assets).
cp -r "$SDK_TESTS/." "$HARNESS_DIR/tests/"

# Rewrite SDK-source imports to the published package. `debugModule` is the only
# symbol not exported by the package, so it is replaced with an inline wrapper.
count=0
while IFS= read -r -d '' f; do
  sed -E \
    -e 's#import \{ NegotiateOptions, debugModule \} from "(\.\./)+src/common/utils";#import { NegotiateOptions } from "@azure/web-pubsub-socket.io";\nimport createDebug from "debug";\nconst debugModule = (namespace: string) => createDebug(namespace);#' \
    -e 's#import \{ debugModule \} from "(\.\./)+src/common/utils";#import createDebug from "debug";\nconst debugModule = (namespace: string) => createDebug(namespace);#' \
    -e 's#import "(\.\./)+src";#import "@azure/web-pubsub-socket.io";#' \
    -e 's#from "(\.\./)+src";#from "@azure/web-pubsub-socket.io";#' \
    "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
  count=$((count + 1))
done < <(find "$HARNESS_DIR/tests" -name '*.ts' -print0)

echo "  prepared $count test file(s) under tests/ (SDK-source imports rewritten to @azure/web-pubsub-socket.io)"
