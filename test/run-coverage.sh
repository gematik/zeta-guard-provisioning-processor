#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="${TOOLS_PATH:-/opt/provisioning-tools}"

cd "$SRC_DIR"

bashcov --root "$SRC_DIR" -- "$SCRIPT_DIR/run-tests.sh"
test_exit=$?

ruby "$SCRIPT_DIR/resultset-to-sonar-coverage.rb" \
  "$SRC_DIR/coverage/.resultset.json" \
  "$SRC_DIR/coverage/coverage.xml"

echo ""
echo "Coverage report: $SRC_DIR/coverage"

exit "$test_exit"
