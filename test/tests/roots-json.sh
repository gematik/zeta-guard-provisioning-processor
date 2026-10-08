#!/usr/bin/env bash

source "$(cd "$(dirname "$0")/../lib" && pwd)/test-helpers.sh"

setup() {
  _CLEANUP_DIR=$(mktemp -d)
  export PROVISIONING_FILES_ROOT="$TEST_DIR"
  export RESULT_DIR="$_CLEANUP_DIR"
  export PROCESSORS_PATH
}

teardown() {
  rm -rf "$_CLEANUP_DIR"
}

# --- tests ---

test_happy_path() {
  setup
  "$PROCESSORS_PATH/roots-json/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/roots.json"

  [ -f "$RESULT_FILE" ] || { fail "roots.json not created"; teardown; return; }
  jq empty "$RESULT_FILE" 2>/dev/null || { fail "roots.json is not valid JSON"; teardown; return; }
  diff -q "$PROVISIONING_FILES_ROOT/roots.json" "$RESULT_FILE" > /dev/null 2>&1 \
    || { fail "roots.json content differs from source"; teardown; return; }

  pass "happy path"
  teardown
}

test_missing_source_file() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"

  if "$PROCESSORS_PATH/roots-json/transform.sh" > /dev/null 2>&1; then
    fail "missing roots.json should cause failure"
  else
    pass "missing roots.json exits non-zero"
  fi
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_missing_result_dir() {
  setup
  export RESULT_DIR="/nonexistent/path"

  if "$PROCESSORS_PATH/roots-json/transform.sh" > /dev/null 2>&1; then
    fail "missing RESULT_DIR should cause failure"
  else
    pass "missing RESULT_DIR exits non-zero"
  fi
  teardown
}

# --- run ---

echo "=== roots-json ==="
test_happy_path
test_missing_source_file
test_missing_result_dir

echo "  ($PASSED passed, $FAILED failed)"
exit $FAILED
