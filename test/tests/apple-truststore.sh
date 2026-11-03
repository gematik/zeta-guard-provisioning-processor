#!/usr/bin/env bash

source "$(cd "$(dirname "$0")/../lib" && pwd)/test-helpers.sh"

echo "PROCESSORS_PATH: $PROCESSORS_PATH"

setup() {
  _CLEANUP_DIR=$(mktemp -d)

  export PROVISIONING_FILES_ROOT="$TEST_DIR"
  export RESULT_DIR="$_CLEANUP_DIR"
  export PROCESSORS_PATH
  export TRUSTSTORE_PASS=jens
}

teardown() {
  rm -rf "$_CLEANUP_DIR"
}

test_happy_path() {
  setup

  "$PROCESSORS_PATH/apple/transform.sh"

  RESULT_FILE="$RESULT_DIR/apple-trust-roots.p12"

  [ -f "$RESULT_FILE" ] || { fail "apple-trust-roots.p12 not created"; teardown; return; }

  openssl pkcs12 -in "$RESULT_FILE" -passin pass:"$TRUSTSTORE_PASS" 2>/dev/null \
    || { fail "openssl cannot parse the trust store"; teardown; return; }

  pass "happy path"
  teardown
}

# --- run ---

echo "=== apple-truststore ==="
test_happy_path

echo "  ($PASSED passed, $FAILED failed)"
exit $FAILED
