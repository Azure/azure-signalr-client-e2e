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
#  We copy the suite and rewrite imports into the SDK source tree so the      #
#  same tests run against either the source-packed (dev) or npm (stable) SDK: #
#    - `../src`               -> @azure/web-pubsub-socket.io (public entry)    #
#    - `../src/common/utils`  -> public `NegotiateOptions` + an inline `debug` #
#                                wrapper for `debugModule`.                   #
#    - `../src/...`           -> @azure/web-pubsub-socket.io/dist/...         #
#                                (compiled internal modules in both packs).  #
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
    -e 's#from "(\.\./)+src/([^"]+)";#from "@azure/web-pubsub-socket.io/dist/\2";#' \
    -e 's#^  it\.each\(\["invalid-json", "0\{\}"\]\)\("rejects an invalid handshake body: %s", async \(body\) => \{#  for (const body of ["invalid-json", "0{}"]) it(`rejects an invalid handshake body: ${body}`, async () => {#' \
    "$f" > "$f.tmp"
  if grep -qE '(^|[^[:alnum:]_])jest(\.|[[:space:]]*$)' "$f.tmp"; then
    sed -i '1i import * as jest from "jest-mock";' "$f.tmp"
  fi
  mv "$f.tmp" "$f"
  count=$((count + 1))
done < <(find "$HARNESS_DIR/tests" -name '*.ts' -print0)

if grep -R -nE "from [\"'](\.\./)+src(/|[\"'])" "$HARNESS_DIR/tests"; then
  echo "ERROR: Socket.IO tests still import SDK source outside the artifact" >&2
  exit 1
fi

if grep -R -nE '\b(it|test|describe)\.each\(' "$HARNESS_DIR/tests"; then
  echo "ERROR: Socket.IO tests contain Jest-only parameterized cases unsupported by Mocha" >&2
  exit 1
fi

while IFS= read -r module; do
  if ! (cd "$HARNESS_DIR" && node -e 'require.resolve(process.argv[1])' "$module"); then
    echo "ERROR: Socket.IO SDK package is missing $module" >&2
    exit 1
  fi
done < <(grep -rhoE '@azure/web-pubsub-socket\.io/dist/[A-Za-z0-9_./-]+' "$HARNESS_DIR/tests" | sort -u)

echo "  prepared $count test file(s) under tests/ (SDK-source imports rewritten to the packaged SDK)"
