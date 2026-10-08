#!/usr/bin/env bash

source "$(cd "$(dirname "$0")/../lib" && pwd)/test-helpers.sh"

TRUSTSTORE_PASS="test"

setup() {
  _CLEANUP_DIR=$(mktemp -d)
  export PROVISIONING_FILES_ROOT="$TEST_DIR"
  export RESULT_DIR="$_CLEANUP_DIR"
  export PROCESSORS_PATH TRUSTSTORE_PASS
  unset TPM_CAB_FILENAME
  unset TPM_RESULT_FILENAME
}

teardown() {
  rm -rf "$_CLEANUP_DIR"
}

# --- helpers ---

assert_no_valid_p12() {
  local test_name="$1"
  local exit_code="$2"
  local p12_file="$RESULT_DIR/tpm-trust-roots.p12"

  if [ $exit_code -ne 0 ]; then
    pass "$test_name exits non-zero"
    return
  fi

  if [ ! -f "$p12_file" ]; then
    fail "$test_name: exit 0 but no output file (should exit non-zero)"
    return
  fi

  CERT_COUNT=$(openssl pkcs12 -in "$p12_file" -passin "pass:$TRUSTSTORE_PASS" -nokeys 2>/dev/null | grep -c "BEGIN CERTIFICATE" || true)
  if [ "$CERT_COUNT" -ge 1 ]; then
    fail "$test_name: produced valid p12 with $CERT_COUNT certs"
  else
    fail "$test_name: exit 0 with empty p12 (should exit non-zero)"
  fi
}

# --- tests ---

test_happy_path() {
  setup
  "$PROCESSORS_PATH/tpm/transform.sh" > /dev/null 2>&1

  P12_FILE="$RESULT_DIR/tpm-trust-roots.p12"

  [ -f "$P12_FILE" ] || { fail "p12 not created"; teardown; return; }
  openssl pkcs12 -in "$P12_FILE" -passin "pass:$TRUSTSTORE_PASS" -nokeys -info > /dev/null 2>&1 \
    || { fail "p12 is not valid"; teardown; return; }

  CERT_COUNT=$(openssl pkcs12 -in "$P12_FILE" -passin "pass:$TRUSTSTORE_PASS" -nokeys 2>/dev/null | grep -c "BEGIN CERTIFICATE" || true)
  [ "$CERT_COUNT" -ge 1 ] || { fail "p12 contains no certificates"; teardown; return; }

  pass "happy path ($CERT_COUNT certs)"
  teardown
}

test_missing_cab_file() {
  setup
  export TPM_CAB_FILENAME="does-not-exist.cab"

  "$PROCESSORS_PATH/tpm/transform.sh" > /dev/null 2>&1
  assert_no_valid_p12 "missing CAB file" $?
  teardown
}

test_corrupt_cab_file() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  echo "not a cab file" > "$TEMP_INPUT_DIR/corrupt.cab"
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"
  export TPM_CAB_FILENAME="corrupt.cab"

  "$PROCESSORS_PATH/tpm/transform.sh" > /dev/null 2>&1
  assert_no_valid_p12 "corrupt CAB file" $?
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_missing_result_dir() {
  setup
  export RESULT_DIR="/nonexistent/path"

  if "$PROCESSORS_PATH/tpm/transform.sh" > /dev/null 2>&1; then
    fail "missing RESULT_DIR should cause failure"
  else
    pass "missing RESULT_DIR exits non-zero"
  fi
  teardown
}

test_custom_result_filename() {
  setup
  export TPM_RESULT_FILENAME="custom-tpm.p12"
  "$PROCESSORS_PATH/tpm/transform.sh" > /dev/null 2>&1

  [ -f "$RESULT_DIR/custom-tpm.p12" ] || { fail "custom filename not used"; teardown; return; }
  [ ! -f "$RESULT_DIR/tpm-trust-roots.p12" ] || { fail "default filename should not exist"; teardown; return; }
  openssl pkcs12 -in "$RESULT_DIR/custom-tpm.p12" -passin "pass:$TRUSTSTORE_PASS" -nokeys -info > /dev/null 2>&1 \
    || { fail "custom output is not a valid p12"; teardown; return; }

  pass "custom result filename"
  teardown
}

# --- run ---

echo "=== tpm ==="
test_happy_path
test_missing_cab_file
test_corrupt_cab_file
test_missing_result_dir
test_custom_result_filename

echo "  ($PASSED passed, $FAILED failed)"
exit $FAILED
