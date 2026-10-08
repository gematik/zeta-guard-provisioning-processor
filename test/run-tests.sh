#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=0

for test_script in "$SCRIPT_DIR"/tests/*.sh; do
  bash "$test_script"
  FAILED=$((FAILED + $?))
done

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "All tests passed."
else
  echo "$FAILED test(s) failed."
  exit 1
fi
