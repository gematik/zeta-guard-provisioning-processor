#!/usr/bin/env bash

source "$(cd "$(dirname "$0")/../lib" && pwd)/test-helpers.sh"

setup() {
  _CLEANUP_DIR=$(mktemp -d)

  export STUB_LOG="$_CLEANUP_DIR/stub.log"
  touch "$STUB_LOG"

# will be created in fetch-provisioning-container.sh
  export PROVISIONING_FILES_ROOT="$_CLEANUP_DIR/rootfs"

  export PROVISIONING_CONTAINER_NAME="registry.example.com/org/image:v1"
  export TRUST_CERTCHAIN_FILE="$_CLEANUP_DIR/chain.pem"
  touch "$TRUST_CERTCHAIN_FILE"

  unset PROVISIONING_CONTAINER_REGISTRY_CA_FILE
  unset PROVISIONING_CONTAINER_REGISTRY_USERNAME
  unset PROVISIONING_CONTAINER_REGISTRY_TOKEN
  unset REGISTRY_CA_FILE
  unset DOCKER_CONFIG
  unset COSIGN_STUB_FAIL_ON
  unset COSIGN_STUB_LAYER_COUNT

  export PATH="$TEST_DIR/stubs:$PATH"
}

teardown() {
  rm -rf "$_CLEANUP_DIR"
}

# --- tests: defaults ---

test_default_container_name() {
  setup
  unset PROVISIONING_CONTAINER_NAME

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  if grep -q "europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-provisioning/zeta-guard-provisioning:latest" "$STUB_LOG"; then
    pass "default container name used"
  else
    fail "default container name not used in cosign call"
  fi
  teardown
}

# --- tests: auth ---

test_anonymous_access_no_login() {
  setup

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  if grep -q "cosign login" "$STUB_LOG"; then
    fail "cosign login should not be called for anonymous access"
  else
    pass "anonymous access: no cosign login"
  fi
  teardown
}

test_authenticated_access_login_called() {
  setup
  export PROVISIONING_CONTAINER_REGISTRY_USERNAME="user"
  export PROVISIONING_CONTAINER_REGISTRY_TOKEN="secret"

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  if grep -q "cosign login" "$STUB_LOG"; then
    pass "authenticated access: cosign login called"
  else
    fail "cosign login should be called when credentials are set"
  fi
  teardown
}

test_authenticated_access_registry_host_extracted() {
  setup
  export PROVISIONING_CONTAINER_REGISTRY_USERNAME="user"
  export PROVISIONING_CONTAINER_REGISTRY_TOKEN="secret"
  export PROVISIONING_CONTAINER_NAME="my-registry.io/org/repo:tag"

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  if grep -q "cosign login my-registry.io" "$STUB_LOG"; then
    pass "registry host correctly extracted"
  else
    fail "registry host not correctly extracted from image name"
    echo "    STUB_LOG: $(cat "$STUB_LOG")"
  fi
  teardown
}

# cosign login has no registry TLS flags, so it must never be passed --registry-cacert,
# not even when a registry CA is configured (ANFTI2-912).
test_login_never_uses_registry_cacert() {
  setup
  export PROVISIONING_CONTAINER_REGISTRY_USERNAME="user"
  export PROVISIONING_CONTAINER_REGISTRY_TOKEN="secret"
  export PROVISIONING_CONTAINER_REGISTRY_CA_FILE="$TRUST_CERTCHAIN_FILE"

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  LOGIN_LINE=$(grep "cosign login" "$STUB_LOG")
  if [ -z "$LOGIN_LINE" ]; then
    fail "cosign login not called"
    teardown; return
  fi

  if echo "$LOGIN_LINE" | grep -q "registry-cacert"; then
    fail "cosign login must NOT use --registry-cacert (unsupported flag)"
    echo "    got: $LOGIN_LINE"
  else
    pass "cosign login without --registry-cacert when CA file set"
  fi
  teardown
}

test_save_uses_registry_cacert_when_ca_file_set() {
  setup
  export PROVISIONING_CONTAINER_REGISTRY_USERNAME="user"
  export PROVISIONING_CONTAINER_REGISTRY_TOKEN="secret"
  export PROVISIONING_CONTAINER_REGISTRY_CA_FILE="$TRUST_CERTCHAIN_FILE"

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  SAVE_CA=$(grep "cosign save" "$STUB_LOG" | grep -o -- '--registry-cacert=[^ ]*' | cut -d= -f2)
  if [ "$SAVE_CA" = "$PROVISIONING_CONTAINER_REGISTRY_CA_FILE" ]; then
    pass "cosign save uses --registry-cacert with the configured CA file"
  else
    fail "cosign save should use --registry-cacert=$PROVISIONING_CONTAINER_REGISTRY_CA_FILE"
    echo "    got: $(grep "cosign save" "$STUB_LOG")"
  fi
  teardown
}

# --- tests: verify & integrity ---

test_cosign_verify_called_with_correct_args() {
  setup

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  if grep -q "cosign verify" "$STUB_LOG"; then
    VERIFY_LINE=$(grep "cosign verify" "$STUB_LOG")
    CHECKS_PASSED=true
    echo "$VERIFY_LINE" | grep -q "certificate-chain" || CHECKS_PASSED=false
    echo "$VERIFY_LINE" | grep -q "certificate-identity software-development@gematik.de" || CHECKS_PASSED=false
    echo "$VERIFY_LINE" | grep -q "insecure-ignore-tlog" || CHECKS_PASSED=false
    echo "$VERIFY_LINE" | grep -q "insecure-ignore-sct" || CHECKS_PASSED=false
    echo "$VERIFY_LINE" | grep -q "local-image" || CHECKS_PASSED=false

    if [ "$CHECKS_PASSED" = "true" ]; then
      pass "cosign verify called with correct arguments"
    else
      fail "cosign verify missing expected arguments"
      echo "    got: $VERIFY_LINE"
    fi
  else
    fail "cosign verify not called"
  fi
  teardown
}

test_save_before_verify() {
  setup

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  SAVE_LINE=$(grep -n "cosign save" "$STUB_LOG" | head -1 | cut -d: -f1)
  VERIFY_LINE=$(grep -n "cosign verify" "$STUB_LOG" | head -1 | cut -d: -f1)

  if [ -z "$SAVE_LINE" ] || [ -z "$VERIFY_LINE" ]; then
    fail "save or verify not found in stub log"
    teardown; return
  fi

  if [ "$SAVE_LINE" -lt "$VERIFY_LINE" ]; then
    pass "save runs before verify (save line $SAVE_LINE, verify line $VERIFY_LINE)"
  else
    fail "save should run before verify (save line $SAVE_LINE, verify line $VERIFY_LINE)"
  fi
  teardown
}

test_verify_uses_same_dir_as_save() {
  setup

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  SAVE_DIR=$(grep "cosign save" "$STUB_LOG" | grep -o -- '--dir [^ ]*' | cut -d' ' -f2)
  VERIFY_DIR=$(grep "cosign verify" "$STUB_LOG" | grep -o -- '--local-image [^ ]*' | cut -d' ' -f2)

  if [ -z "$SAVE_DIR" ] || [ -z "$VERIFY_DIR" ]; then
    fail "could not extract dirs from stub log"
    teardown; return
  fi

  if [ "$SAVE_DIR" = "$VERIFY_DIR" ]; then
    pass "verify operates on same dir as save"
  else
    fail "verify dir ($VERIFY_DIR) differs from save dir ($SAVE_DIR)"
  fi
  teardown
}

# --- tests: extraction & cleanup ---

test_layer_extraction() {
  setup

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  if [ -f "$PROVISIONING_FILES_ROOT/layer-1.txt" ]; then
    pass "layer extracted to PROVISIONING_FILES_ROOT"
  else
    fail "layer not extracted to PROVISIONING_FILES_ROOT"
    echo "    contents: $(ls -la "$PROVISIONING_FILES_ROOT" 2>&1)"
  fi
  teardown
}

test_multiple_layers_extracted() {
  setup
  export COSIGN_STUB_LAYER_COUNT=3

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  EXTRACTED=0
  for i in 1 2 3; do
    [ -f "$PROVISIONING_FILES_ROOT/layer-${i}.txt" ] && EXTRACTED=$((EXTRACTED + 1))
  done

  if [ "$EXTRACTED" -eq 3 ]; then
    pass "multiple layers all extracted ($EXTRACTED/3)"
  else
    fail "not all layers extracted ($EXTRACTED/3)"
    echo "    contents: $(ls "$PROVISIONING_FILES_ROOT" 2>&1)"
  fi
  teardown
}

test_temp_dir_cleaned_up() {
  setup

  BEFORE=$(find /tmp -maxdepth 1 -name "tmp.*" -type d | sort)
  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1
  AFTER=$(find /tmp -maxdepth 1 -name "tmp.*" -type d | sort)

  NEW_DIRS=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER"))
  if [ -z "$NEW_DIRS" ]; then
    pass "temp download dir cleaned up"
  else
    fail "temp download dir not cleaned up: $NEW_DIRS"
  fi
  teardown
}

# --- tests: error handling ---

test_missing_trust_certchain_file() {
  setup
  unset TRUST_CERTCHAIN_FILE

  if "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1; then
    fail "missing TRUST_CERTCHAIN_FILE should exit non-zero"
  else
    pass "missing TRUST_CERTCHAIN_FILE exits non-zero"
  fi
  teardown
}

test_empty_trust_certchain_file() {
  setup
  export TRUST_CERTCHAIN_FILE=""

  if "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1; then
    fail "empty TRUST_CERTCHAIN_FILE should exit non-zero"
  else
    pass "empty TRUST_CERTCHAIN_FILE exits non-zero"
  fi
  teardown
}

test_username_without_token() {
  setup
  export PROVISIONING_CONTAINER_REGISTRY_USERNAME="user"
  unset PROVISIONING_CONTAINER_REGISTRY_TOKEN

  if "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1; then
    fail "username without token should exit non-zero"
  else
    pass "username without token exits non-zero"
  fi
  teardown
}

test_token_without_username() {
  setup
  unset PROVISIONING_CONTAINER_REGISTRY_USERNAME
  export PROVISIONING_CONTAINER_REGISTRY_TOKEN="secret"

  if "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1; then
    fail "token without username should exit non-zero"
  else
    pass "token without username exits non-zero"
  fi
  teardown
}

test_cosign_login_failure_aborts() {
  setup
  export PROVISIONING_CONTAINER_REGISTRY_USERNAME="user"
  export PROVISIONING_CONTAINER_REGISTRY_TOKEN="secret"
  export COSIGN_STUB_FAIL_ON="login"

  if "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1; then
    fail "cosign login failure should abort script"
  else
    pass "cosign login failure aborts script"
  fi
  teardown
}

test_cosign_save_failure_aborts() {
  setup
  export COSIGN_STUB_FAIL_ON="save"

  if "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1; then
    fail "cosign save failure should abort script"
  else
    pass "cosign save failure aborts script"
  fi
  teardown
}

test_cosign_verify_failure_aborts() {
  setup
  export COSIGN_STUB_FAIL_ON="verify"

  if "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1; then
    fail "cosign verify failure should abort script"
  else
    pass "cosign verify failure aborts script"
  fi
  teardown
}

test_no_extraction_when_verify_fails() {
  setup
  export COSIGN_STUB_FAIL_ON="verify"

  "$PROCESSORS_PATH/../fetch-provisioning-container.sh" > /dev/null 2>&1

  if [ "$(ls -A "$PROVISIONING_FILES_ROOT")" = "" ]; then
    pass "no files extracted when verify fails"
  else
    fail "files extracted despite verify failure"
    echo "    contents: $(ls "$PROVISIONING_FILES_ROOT" 2>&1)"
  fi
  teardown
}

# --- run ---

echo "=== fetch-provisioning-container ==="

# defaults
test_default_container_name

# auth
test_anonymous_access_no_login
test_authenticated_access_login_called
test_authenticated_access_registry_host_extracted
test_login_never_uses_registry_cacert
test_save_uses_registry_cacert_when_ca_file_set

# verify & integrity
test_cosign_verify_called_with_correct_args
test_save_before_verify
test_verify_uses_same_dir_as_save

# extraction & cleanup
test_layer_extraction
test_multiple_layers_extracted
test_temp_dir_cleaned_up

# error handling
test_missing_trust_certchain_file
test_empty_trust_certchain_file
test_username_without_token
test_token_without_username
test_cosign_login_failure_aborts
test_cosign_save_failure_aborts
test_cosign_verify_failure_aborts
test_no_extraction_when_verify_fails

echo "  ($PASSED passed, $FAILED failed)"
exit $FAILED
