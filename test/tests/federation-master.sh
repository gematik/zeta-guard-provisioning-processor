#!/usr/bin/env bash

source "$(cd "$(dirname "$0")/../lib" && pwd)/test-helpers.sh"

setup() {
  _CLEANUP_DIR=$(mktemp -d)
  export PROVISIONING_FILES_ROOT="$TEST_DIR"
  export RESULT_DIR="$_CLEANUP_DIR"
  export PROCESSORS_PATH
  export FEDERATION_MASTER_ENVIRONMENT="production"
  unset FEDERATION_MASTER_FILENAME
  unset FEDERATION_MASTER_RESULT_FILENAME
  unset DEV_MODE
  unset FEDMASTER_URL
}

teardown() {
  rm -rf "$_CLEANUP_DIR"
}

# --- tests ---

test_happy_path() {
  setup
  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/federation-master.json"

  [ -f "$RESULT_FILE" ] || { fail "federation-master.json not created"; teardown; return; }
  jq empty "$RESULT_FILE" 2>/dev/null || { fail "federation-master.json is not valid JSON"; teardown; return; }

  URL=$(jq -r '.fedmasterUrl' "$RESULT_FILE")
  [ "$URL" = "https://app.federationmaster.de" ] \
    || { fail "expected production URL, got $URL"; teardown; return; }

  pass "happy path"
  teardown
}

test_json_structure() {
  setup
  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/federation-master.json"

  [ -f "$RESULT_FILE" ] || { fail "federation-master.json not created"; teardown; return; }

  KEYS=$(jq -r 'keys | sort | join(",")' "$RESULT_FILE")
  [ "$KEYS" = "fedmasterUrl" ] || { fail "unexpected JSON keys: $KEYS"; teardown; return; }

  URL=$(jq -r '.fedmasterUrl' "$RESULT_FILE")
  [[ "$URL" == https://* ]] || { fail "fedmasterUrl is not an https URL: $URL"; teardown; return; }

  pass "json structure"
  teardown
}

test_select_test_environment() {
  setup
  export FEDERATION_MASTER_ENVIRONMENT="test"
  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/federation-master.json"
  [ -f "$RESULT_FILE" ] || { fail "federation-master.json not created"; teardown; return; }

  URL=$(jq -r '.fedmasterUrl' "$RESULT_FILE")
  [ "$URL" = "https://app-test.federationmaster.de" ] \
    || { fail "expected test URL, got $URL"; teardown; return; }

  pass "select test environment"
  teardown
}

test_missing_environment_var() {
  setup
  unset FEDERATION_MASTER_ENVIRONMENT

  if "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1; then
    fail "missing FEDERATION_MASTER_ENVIRONMENT should cause failure"
  else
    pass "missing FEDERATION_MASTER_ENVIRONMENT exits non-zero"
  fi
  teardown
}

test_unknown_environment() {
  setup
  export FEDERATION_MASTER_ENVIRONMENT="nonexistent"

  if "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1; then
    fail "unknown environment should cause failure"
  else
    pass "unknown environment exits non-zero"
  fi
  teardown
}

test_dev_mode_override() {
  setup
  export DEV_MODE="true"
  export FEDMASTER_URL="https://custom.local/federation"
  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/federation-master.json"
  [ -f "$RESULT_FILE" ] || { fail "federation-master.json not created"; teardown; return; }

  URL=$(jq -r '.fedmasterUrl' "$RESULT_FILE")
  [ "$URL" = "https://custom.local/federation" ] \
    || { fail "expected DEV_MODE URL, got $URL"; teardown; return; }

  pass "dev mode override"
  teardown
}

test_dev_mode_without_url() {
  setup
  export DEV_MODE="true"
  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/federation-master.json"
  [ -f "$RESULT_FILE" ] || { fail "federation-master.json not created"; teardown; return; }

  URL=$(jq -r '.fedmasterUrl' "$RESULT_FILE")
  [ "$URL" = "https://app.federationmaster.de" ] \
    || { fail "DEV_MODE without FEDMASTER_URL should use normal URL, got $URL"; teardown; return; }

  pass "dev mode without FEDMASTER_URL uses normal URL"
  teardown
}

test_dev_mode_disabled_ignores_url() {
  setup
  export DEV_MODE="false"
  export FEDMASTER_URL="https://should-be-ignored.local/federation"
  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/federation-master.json"
  [ -f "$RESULT_FILE" ] || { fail "federation-master.json not created"; teardown; return; }

  URL=$(jq -r '.fedmasterUrl' "$RESULT_FILE")
  [ "$URL" = "https://app.federationmaster.de" ] \
    || { fail "DEV_MODE=false should ignore FEDMASTER_URL, got $URL"; teardown; return; }

  pass "dev mode disabled ignores FEDMASTER_URL"
  teardown
}

test_custom_result_filename() {
  setup
  export FEDERATION_MASTER_RESULT_FILENAME="custom.json"
  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  [ -f "$RESULT_DIR/custom.json" ] || { fail "custom filename not used"; teardown; return; }
  [ ! -f "$RESULT_DIR/federation-master.json" ] || { fail "default filename should not exist"; teardown; return; }
  jq empty "$RESULT_DIR/custom.json" 2>/dev/null || { fail "custom output is not valid JSON"; teardown; return; }

  pass "custom result filename"
  teardown
}

test_custom_input_filename() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  cp "$TEST_DIR/federation-master.yaml" "$TEMP_INPUT_DIR/other.yaml"
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"
  export FEDERATION_MASTER_FILENAME="other.yaml"

  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/federation-master.json"
  [ -f "$RESULT_FILE" ] || { fail "output not created with custom input filename"; teardown; rm -rf "$TEMP_INPUT_DIR"; return; }
  jq empty "$RESULT_FILE" 2>/dev/null || { fail "output is not valid JSON"; teardown; rm -rf "$TEMP_INPUT_DIR"; return; }

  pass "custom input filename"
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_missing_source_file() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"

  if "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1; then
    fail "missing source file should cause failure"
  else
    pass "missing source file exits non-zero"
  fi
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_missing_result_dir() {
  setup
  export RESULT_DIR="/nonexistent/path"

  if "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1; then
    fail "missing RESULT_DIR should cause failure"
  else
    pass "missing RESULT_DIR exits non-zero"
  fi
  teardown
}

test_invalid_url_from_yaml() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  cat > "$TEMP_INPUT_DIR/federation-master.yaml" <<'YAML'
ti_federation_master: [
    {
        environment: production,
        entity_statement_uri: "not-a-url"
    }
]
YAML
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"

  if "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1; then
    fail "invalid URL from YAML should cause failure"
  else
    pass "invalid URL from YAML exits non-zero"
  fi
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_invalid_url_from_dev_mode() {
  setup
  export DEV_MODE="true"
  export FEDMASTER_URL="not-a-url"

  if "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1; then
    fail "invalid DEV_MODE URL should cause failure"
  else
    pass "invalid DEV_MODE URL exits non-zero"
  fi
  teardown
}

test_single_entry() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  cat > "$TEMP_INPUT_DIR/federation-master.yaml" <<'YAML'
ti_federation_master: [
    {
        environment: production,
        entity_statement_uri: "https://app.federationmaster.de/.well-known/openid-federation"
    }
]
YAML
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"

  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/federation-master.json"
  [ -f "$RESULT_FILE" ] || { fail "output not created for single entry"; rm -rf "$TEMP_INPUT_DIR"; teardown; return; }
  jq empty "$RESULT_FILE" 2>/dev/null || { fail "output is not valid JSON"; rm -rf "$TEMP_INPUT_DIR"; teardown; return; }

  URL=$(jq -r '.fedmasterUrl' "$RESULT_FILE")
  [ "$URL" = "https://app.federationmaster.de" ] \
    || { fail "expected production URL, got $URL"; rm -rf "$TEMP_INPUT_DIR"; teardown; return; }

  pass "single entry"
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_duplicate_environment() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  cat > "$TEMP_INPUT_DIR/federation-master.yaml" <<'YAML'
ti_federation_master: [
    {
        environment: production,
        entity_statement_uri: "https://app.federationmaster.de/.well-known/openid-federation"
    },
    {
        environment: production,
        entity_statement_uri: "https://evil.example.com/.well-known/openid-federation"
    }
]
YAML
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"

  if "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1; then
    fail "duplicate environment should cause failure"
  else
    pass "duplicate environment exits non-zero"
  fi
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_http_url_rejected_without_dev_mode() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  cat > "$TEMP_INPUT_DIR/federation-master.yaml" <<'YAML'
ti_federation_master: [
    {
        environment: production,
        entity_statement_uri: "http://insecure.example.com/.well-known/openid-federation"
    }
]
YAML
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"

  if "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1; then
    fail "http:// URL without DEV_MODE should cause failure"
  else
    pass "http:// URL without DEV_MODE exits non-zero"
  fi
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_http_url_allowed_in_dev_mode() {
  setup
  export DEV_MODE="true"
  export FEDMASTER_URL="http://localhost:8080/federation"
  "$PROCESSORS_PATH/federation-master/transform.sh" > /dev/null 2>&1

  RESULT_FILE="$RESULT_DIR/federation-master.json"
  [ -f "$RESULT_FILE" ] || { fail "federation-master.json not created"; teardown; return; }

  URL=$(jq -r '.fedmasterUrl' "$RESULT_FILE")
  [ "$URL" = "http://localhost:8080/federation" ] \
    || { fail "expected http DEV_MODE URL, got $URL"; teardown; return; }

  pass "http:// URL allowed in DEV_MODE"
  teardown
}

# --- run ---

echo "=== federation-master ==="
test_happy_path
test_json_structure
test_select_test_environment
test_missing_environment_var
test_unknown_environment
test_dev_mode_override
test_dev_mode_without_url
test_dev_mode_disabled_ignores_url
test_custom_result_filename
test_custom_input_filename
test_missing_source_file
test_missing_result_dir
test_invalid_url_from_yaml
test_invalid_url_from_dev_mode
test_single_entry
test_duplicate_environment
test_http_url_rejected_without_dev_mode
test_http_url_allowed_in_dev_mode

echo "  ($PASSED passed, $FAILED failed)"
exit "$FAILED"
