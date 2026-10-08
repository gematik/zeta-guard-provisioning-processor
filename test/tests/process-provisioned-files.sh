#!/usr/bin/env bash

source "$(cd "$(dirname "$0")/../lib" && pwd)/test-helpers.sh"

SRC_PATH="${PROCESSORS_PATH}/.."

setup() {
  _CLEANUP_DIR=$(mktemp -d)
  _PROV_ROOT=$(mktemp -d)

  cp "$TEST_DIR/ECC-RSA_TSL-test.xml" "$_PROV_ROOT/"
  cp "$TEST_DIR/TrustedTpm.cab" "$_PROV_ROOT/" 2>/dev/null || true
  cp "$TEST_DIR/roots.json" "$_PROV_ROOT/" 2>/dev/null || true
  cp -r "$TEST_DIR/policy-engine-bundle-keys" "$_PROV_ROOT/" 2>/dev/null || true

  export PROVISIONING_FILES_ROOT="$_PROV_ROOT"
  export RESULT_DIR="$_CLEANUP_DIR"
  export PROCESSORS_PATH
  export TOOLS_PATH="$TEST_DIR/stubs"
  export TRUSTSTORE_PASS="test"
  export TSL_FILENAME="ECC-RSA_TSL-test.xml"
  unset PROCESSORS_TSL_SMB_ENABLED
  unset PROCESSORS_TSL_OCSP_ENABLED
  unset PROCESSORS_TPM_ENABLED
  unset PROCESSORS_POLICY_SIGNER_ENABLED
  unset PROCESSORS_ROOTS_JSON_ENABLED
}

teardown() {
  rm -rf "$_CLEANUP_DIR"
  rm -rf "$_PROV_ROOT"
}

# --- tests ---

test_all_disabled() {
  setup

  OUTPUT=$("$SRC_PATH/process-provisioned-files.sh" 2>&1)
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -ne 0 ]; then
    fail "all disabled: unexpected exit code $EXIT_CODE"
    teardown; return
  fi

  echo "$OUTPUT" | grep -q "tsl smb transformer is disabled" \
    || { fail "all disabled: no smb disabled message"; teardown; return; }
  echo "$OUTPUT" | grep -q "tsl ocsp transformer is disabled" \
    || { fail "all disabled: no ocsp disabled message"; teardown; return; }
  echo "$OUTPUT" | grep -q "tpm transformer is disabled" \
    || { fail "all disabled: no tpm disabled message"; teardown; return; }
  echo "$OUTPUT" | grep -q "policy-signer transformer is disabled" \
    || { fail "all disabled: no policy-signer disabled message"; teardown; return; }
  echo "$OUTPUT" | grep -q "roots-json transformer is disabled" \
    || { fail "all disabled: no roots-json disabled message"; teardown; return; }

  pass "all disabled"
  teardown
}

test_provisioning_files_root_default() {
  setup
  unset PROVISIONING_FILES_ROOT

  OUTPUT=$("$SRC_PATH/process-provisioned-files.sh" 2>&1)

  echo "$OUTPUT" | grep -q "PROVISIONING_FILES_ROOT not defined" \
    || { fail "PROVISIONING_FILES_ROOT default message missing"; teardown; return; }

  pass "PROVISIONING_FILES_ROOT default"
  teardown
}

test_provisioning_files_root_defined() {
  setup

  OUTPUT=$("$SRC_PATH/process-provisioned-files.sh" 2>&1)

  echo "$OUTPUT" | grep -q "Using PROVISIONING_FILES_ROOT as defined" \
    || { fail "PROVISIONING_FILES_ROOT defined message missing"; teardown; return; }

  pass "PROVISIONING_FILES_ROOT defined"
  teardown
}

test_result_dir_not_defined() {
  setup
  unset RESULT_DIR

  OUTPUT=$("$SRC_PATH/process-provisioned-files.sh" 2>&1)
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -eq 0 ]; then
    fail "RESULT_DIR not defined: expected non-zero exit code"
    teardown; return
  fi

  echo "$OUTPUT" | grep -q "ERROR: RESULT_DIR not defined" \
    || { fail "RESULT_DIR not defined: error message missing"; teardown; return; }

  pass "RESULT_DIR not defined"
  teardown
}

test_result_dir_defined() {
  setup

  OUTPUT=$("$SRC_PATH/process-provisioned-files.sh" 2>&1)

  echo "$OUTPUT" | grep -q "Using RESULT_DIR as defined" \
    || { fail "RESULT_DIR defined message missing"; teardown; return; }

  pass "RESULT_DIR defined"
  teardown
}

test_truststore_pass_default() {
  setup
  unset TRUSTSTORE_PASS

  OUTPUT=$("$SRC_PATH/process-provisioned-files.sh" 2>&1)

  echo "$OUTPUT" | grep -q "TRUSTSTORE_PASS not defined, using the default" \
    || { fail "TRUSTSTORE_PASS default message missing"; teardown; return; }

  pass "TRUSTSTORE_PASS default"
  teardown
}

test_truststore_pass_defined() {
  setup

  OUTPUT=$("$SRC_PATH/process-provisioned-files.sh" 2>&1)

  echo "$OUTPUT" | grep -q "Using TRUSTSTORE_PASS as defined per env variable" \
    || { fail "TRUSTSTORE_PASS defined message missing"; teardown; return; }

  pass "TRUSTSTORE_PASS defined"
  teardown
}

test_smb_enabled() {
  setup
  export PROCESSORS_TSL_SMB_ENABLED="true"

  "$SRC_PATH/process-provisioned-files.sh" > /dev/null 2>&1

  [ -f "$RESULT_DIR/smcb-trust-roots.p12" ] \
    || { fail "smb enabled: p12 not created"; teardown; return; }

  pass "smb enabled"
  teardown
}

test_ocsp_enabled() {
  setup
  export PROCESSORS_TSL_OCSP_ENABLED="true"

  "$SRC_PATH/process-provisioned-files.sh" > /dev/null 2>&1

  [ -f "$RESULT_DIR/ocsp-signers.p12" ] \
    || { fail "ocsp enabled: p12 not created"; teardown; return; }

  pass "ocsp enabled"
  teardown
}

test_tpm_enabled() {
  setup
  export PROCESSORS_TPM_ENABLED="true"

  "$SRC_PATH/process-provisioned-files.sh" > /dev/null 2>&1

  [ -f "$RESULT_DIR/tpm-trust-roots.p12" ] \
    || { fail "tpm enabled: p12 not created"; teardown; return; }

  pass "tpm enabled"
  teardown
}

test_policy_signer_enabled() {
  setup
  export PROCESSORS_POLICY_SIGNER_ENABLED="true"

  "$SRC_PATH/process-provisioned-files.sh" > /dev/null 2>&1

  [ -f "$RESULT_DIR/policy-signer.pub" ] \
    || { fail "policy-signer enabled: pub not created"; teardown; return; }

  pass "policy-signer enabled"
  teardown
}

test_roots_json_enabled() {
  setup
  export PROCESSORS_ROOTS_JSON_ENABLED="true"

  "$SRC_PATH/process-provisioned-files.sh" > /dev/null 2>&1

  [ -f "$RESULT_DIR/roots.json" ] \
    || { fail "roots-json enabled: file not created"; teardown; return; }

  pass "roots-json enabled"
  teardown
}

test_cleanup_provisioning_files_root() {
  setup

  "$SRC_PATH/process-provisioned-files.sh" > /dev/null 2>&1

  if [ -d "$PROVISIONING_FILES_ROOT" ]; then
    fail "PROVISIONING_FILES_ROOT not cleaned up"
  else
    pass "PROVISIONING_FILES_ROOT cleaned up"
  fi
  _PROV_ROOT=""
  teardown
}

# --- run ---

echo "=== process-provisioned-files ==="
test_all_disabled
test_provisioning_files_root_default
test_provisioning_files_root_defined
test_result_dir_not_defined
test_result_dir_defined
test_truststore_pass_default
test_truststore_pass_defined
test_smb_enabled
test_ocsp_enabled
test_tpm_enabled
test_policy_signer_enabled
test_roots_json_enabled
test_cleanup_provisioning_files_root

echo "  ($PASSED passed, $FAILED failed)"
exit $FAILED
