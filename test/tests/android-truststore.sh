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

  "$PROCESSORS_PATH/android/transform.sh"

  RESULT_FILE="$RESULT_DIR/google-trust-roots.p12"

  [ -f "$RESULT_FILE" ] || { fail "google-trust-roots.p12 not created"; teardown; return; }

  openssl pkcs12 -in "$RESULT_FILE" -passin pass:"$TRUSTSTORE_PASS" 2>/dev/null \
    || { fail "openssl cannot parse the trust store"; teardown; return; }

  RESULT_FILE="$RESULT_DIR/google-certificate-status.json"

  [ -f "$RESULT_FILE" ] || { fail "google-certificate-status.json not created"; teardown; return; }

  length="$(jq 'length' < "$RESULT_FILE")"

  [ "$length" == 1 ] || { fail "google-certificate-status.json contains no data"; teardown; return; }

  pass "happy path"
  teardown
}

test_download_status() {
  setup
  export ANDROID_ROOT_STATUS_FILENAME="./jens.json"

  "$PROCESSORS_PATH/android/transform.sh"

  RESULT_FILE="$RESULT_DIR/google-trust-roots.p12"

  [ -f "$RESULT_FILE" ] || { fail "google-trust-roots.p12 not created"; teardown; return; }

  openssl pkcs12 -in "$RESULT_FILE" -passin pass:"$TRUSTSTORE_PASS" 2>/dev/null \
    || { fail "openssl cannot parse the trust store"; teardown; return; }

  RESULT_FILE="$RESULT_DIR/google-certificate-status.json"

  [ -f "$RESULT_FILE" ] || { fail "google-certificate-status.json not created"; teardown; return; }

  length="$(jq 'length' < "$RESULT_FILE")"

  [ "$length" == 1 ] || { fail "google-certificate-status.json contains no data"; teardown; return; }

  pass "download status workaround"
  teardown
}

# --- run ---

echo "=== android-truststore ==="

test_happy_path

test_download_status

echo "  ($PASSED passed, $FAILED failed)"
exit $FAILED
