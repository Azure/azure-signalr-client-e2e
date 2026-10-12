#!/usr/bin/env bash
set -uo pipefail

max_attempts="${MAX_ATTEMPTS:-3}"
if [[ ! "$max_attempts" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: MAX_ATTEMPTS must be a positive integer" >&2
  exit 1
fi

result_log=$(mktemp)
trap 'rm -f "$result_log"' EXIT

echo "=== Chat Client full suite (attempt 1 / $max_attempts) ==="
if npm test 2>&1 | tee "$result_log"; then
  if grep -Eq '^# tests [1-9][0-9]*$' "$result_log" &&
     grep -q '^# fail 0$' "$result_log" &&
     grep -q '^# cancelled 0$' "$result_log" &&
     grep -q '^# skipped 0$' "$result_log"; then
    exit 0
  fi
fi

if ! grep -Eq '^# tests [1-9][0-9]*$' "$result_log"; then
  echo "ERROR: Chat Client suite exited without a complete TAP summary" >&2
  exit 1
fi

mapfile -t failed_tests < <(sed -nE 's/^not ok [0-9]+ - (.+)$/\1/p' "$result_log")
if (( ${#failed_tests[@]} == 0 )); then
  echo "ERROR: Chat Client suite failed without a named failing test" >&2
  exit 1
fi

result=0
for name in "${failed_tests[@]}"; do
  pattern=$(node -e 'console.log("^" + process.argv[1].replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$")' "$name")
  passed=0
  for ((attempt=2; attempt<=max_attempts; attempt++)); do
    echo "=== Retrying Chat Client: $name (attempt $attempt / $max_attempts) ==="
    : > "$result_log"
    if node ./node_modules/tsx/dist/cli.mjs --test --test-name-pattern="$pattern" tests/integration.test.ts 2>&1 | tee "$result_log" &&
       grep -q '^# pass 1$' "$result_log" &&
       grep -q '^# fail 0$' "$result_log" &&
       grep -q '^# cancelled 0$' "$result_log"; then
      passed=1
      break
    fi
    if (( attempt < max_attempts )); then
      sleep $(( (RANDOM % 11 + 5) * attempt ))
    fi
  done
  if (( ! passed )); then
    echo "ERROR: Chat Client test did not pass: $name" >&2
    result=1
  fi
done

exit "$result"
