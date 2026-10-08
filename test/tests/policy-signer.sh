#!/usr/bin/env bash

source "$(cd "$(dirname "$0")/../lib" && pwd)/test-helpers.sh"

setup() {
  _CLEANUP_DIR=$(mktemp -d)
  export PROVISIONING_FILES_ROOT="$TEST_DIR"
  export RESULT_DIR="$_CLEANUP_DIR"
  export PROCESSORS_PATH
  unset POLICY_SIGNER_CERT_FILENAME
  unset POLICY_RESULT_FILENAME
}

teardown() {
  rm -rf "$_CLEANUP_DIR"
}

# --- helpers ---

assert_no_valid_output() {
  local test_name="$1"
  local exit_code="$2"
  local result_file="$RESULT_DIR/policy-signer.pub"

  if [ $exit_code -ne 0 ]; then
    pass "$test_name exits non-zero"
  elif [ -f "$result_file" ] && openssl pkey -pubin -in "$result_file" -noout 2>/dev/null; then
    fail "$test_name: produced a valid public key"
  else
    fail "$test_name: exit 0 with no valid output (should exit non-zero)"
  fi
}

# --- tests ---

test_happy_path() {
  setup
  "$PROCESSORS_PATH/policy-signer/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/policy-signer.pub"

  [ -f "$RESULT_FILE" ] || { fail "policy-signer.pub not created"; teardown; return; }
  openssl pkey -pubin -in "$RESULT_FILE" -noout 2>/dev/null \
    || { fail "openssl cannot parse the public key"; teardown; return; }

  pass "happy path"
  teardown
}

test_missing_signers_dir() {
  setup
  PROVISIONING_FILES_ROOT=$(mktemp -d)
  export PROVISIONING_FILES_ROOT

  "$PROCESSORS_PATH/policy-signer/transform.sh" > /dev/null 2>&1
  assert_no_valid_output "missing signers dir" $?
  rm -rf "$PROVISIONING_FILES_ROOT"
  teardown
}

test_empty_signers_dir() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  mkdir -p "$TEMP_INPUT_DIR/policy-engine-bundle-keys/signers"
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"

  "$PROCESSORS_PATH/policy-signer/transform.sh" > /dev/null 2>&1
  assert_no_valid_output "empty signers dir" $?
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_invalid_certificate() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  mkdir -p "$TEMP_INPUT_DIR/policy-engine-bundle-keys/signers"
  echo "not a certificate" > "$TEMP_INPUT_DIR/policy-engine-bundle-keys/signers/bad.pem"
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"

  "$PROCESSORS_PATH/policy-signer/transform.sh" > /dev/null 2>&1
  assert_no_valid_output "invalid certificate" $?
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_missing_result_dir() {
  setup
  export RESULT_DIR="/nonexistent/path"

  if "$PROCESSORS_PATH/policy-signer/transform.sh" > /dev/null 2>&1; then
    fail "missing RESULT_DIR should cause failure"
  else
    pass "missing RESULT_DIR exits non-zero"
  fi
  teardown
}

test_custom_result_filename() {
  setup
  export POLICY_RESULT_FILENAME="custom-policy.pub"
  "$PROCESSORS_PATH/policy-signer/transform.sh" > /dev/null 2>&1

  [ -f "$RESULT_DIR/custom-policy.pub" ] || { fail "custom filename not used"; teardown; return; }
  [ ! -f "$RESULT_DIR/policy-signer.pub" ] || { fail "default filename should not exist"; teardown; return; }
  openssl pkey -pubin -in "$RESULT_DIR/custom-policy.pub" -noout 2>/dev/null \
    || { fail "custom output is not a valid public key"; teardown; return; }

  pass "custom result filename"
  teardown
}

test_explicit_cert_path() {
  setup
  export POLICY_SIGNER_CERT_FILENAME="$PROVISIONING_FILES_ROOT/policy-engine-bundle-keys/signers/zeta_artifact_reg_nist.pem"
  "$PROCESSORS_PATH/policy-signer/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/policy-signer.pub"
  [ -f "$RESULT_FILE" ] || { fail "output not created with explicit cert path"; teardown; return; }
  openssl pkey -pubin -in "$RESULT_FILE" -noout 2>/dev/null \
    || { fail "output is not a valid public key"; teardown; return; }

  pass "explicit cert path"
  teardown
}

# --- run ---

echo "=== policy-signer ==="
test_happy_path
test_missing_signers_dir
test_empty_signers_dir
test_invalid_certificate
test_missing_result_dir
test_custom_result_filename
test_explicit_cert_path

echo "  ($PASSED passed, $FAILED failed)"
exit $FAILED
