#!/usr/bin/env bash
#
# Parametrised TSL transform test — sourced by tsl-ocsp.sh / tsl-smb.sh wrappers.
#
# Required variables (set by the wrapper before sourcing):
#   PROCESSOR_NAME        e.g. "tsl-ocsp" or "tsl-smb"
#   DEFAULT_P12_NAME      e.g. "ocsp-signers.p12" or "smcb-trust-roots.p12"
#   DEFAULT_META_NAME     e.g. "ocsp-signers-meta.json" or "smcb-trust-roots-meta.json"
#   RESULT_FILENAME_VAR   env var name for custom p12 filename, e.g. "OCSP_RESULT_FILENAME"
#   META_FILENAME_VAR     env var name for custom meta filename, e.g. "OCSP_META_FILENAME"
#   CUSTOM_P12_NAME       e.g. "custom-ocsp.p12"
#   CUSTOM_META_NAME      e.g. "custom-ocsp-meta.json"
#   PEM_XSL_NAME          XSL that produces PEM output, e.g. "tsl-smb-to-pem.xsl"
#   SERVICE_TYPE_ID       ServiceTypeIdentifier for the synthetic TSL entry
#   EXTENSION_OID         OID in ServiceInformationExtensions
#   EXTENSION_VALUE       value for the extension OID
#   NORMAL_FRIENDLY_NAME  a typical name that should pass through unchanged

source "$(cd "$(dirname "$0")/../lib" && pwd)/test-helpers.sh"

TRUSTSTORE_PASS="test"

setup() {
  _CLEANUP_DIR=$(mktemp -d)
  export PROVISIONING_FILES_ROOT="$TEST_DIR"
  export RESULT_DIR="$_CLEANUP_DIR"
  export PROCESSORS_PATH TRUSTSTORE_PASS
  export TSL_FILENAME="ECC-RSA_TSL-test.xml"
  unset "$RESULT_FILENAME_VAR"
  unset "$META_FILENAME_VAR"
}

teardown() {
  rm -rf "$_CLEANUP_DIR"
}

# --- helpers ---

assert_no_valid_output() {
  local test_name="$1"
  local exit_code="$2"
  local p12_file="$RESULT_DIR/$DEFAULT_P12_NAME"
  local meta_file="$RESULT_DIR/$DEFAULT_META_NAME"

  if [ $exit_code -ne 0 ]; then
    pass "$test_name exits non-zero"
    return
  fi

  if [ -f "$p12_file" ]; then
    CERT_COUNT=$(openssl pkcs12 -in "$p12_file" -passin "pass:$TRUSTSTORE_PASS" -nokeys 2>/dev/null | grep -c "BEGIN CERTIFICATE" || true)
    if [ "$CERT_COUNT" -ge 1 ]; then
      fail "$test_name: exit 0 and produced p12 with $CERT_COUNT certs"
      return
    fi
  fi

  if [ -f "$meta_file" ] && [ -s "$meta_file" ]; then
    if jq empty "$meta_file" 2>/dev/null; then
      META_COUNT=$(jq 'length' "$meta_file" 2>/dev/null || echo 0)
      if [ "$META_COUNT" -ge 1 ]; then
        fail "$test_name: exit 0 and produced meta with $META_COUNT entries"
        return
      fi
    fi
  fi

  fail "$test_name: exit 0 with empty output (should exit non-zero)"
}

# --- tests ---

test_happy_path() {
  setup
  "$PROCESSORS_PATH/$PROCESSOR_NAME/transform.sh" > /dev/null 2>&1

  P12_FILE="$RESULT_DIR/$DEFAULT_P12_NAME"
  META_FILE="$RESULT_DIR/$DEFAULT_META_NAME"

  [ -f "$P12_FILE" ] || { fail "p12 not created"; teardown; return; }
  openssl pkcs12 -in "$P12_FILE" -passin "pass:$TRUSTSTORE_PASS" -nokeys -info > /dev/null 2>&1 \
    || { fail "p12 is not valid"; teardown; return; }

  CERT_COUNT=$(openssl pkcs12 -in "$P12_FILE" -passin "pass:$TRUSTSTORE_PASS" -nokeys 2>/dev/null | grep -c "BEGIN CERTIFICATE" || true)
  [ "$CERT_COUNT" -ge 1 ] || { fail "p12 contains no certificates"; teardown; return; }

  [ -f "$META_FILE" ] || { fail "meta file not created"; teardown; return; }
  jq empty "$META_FILE" 2>/dev/null || { fail "meta file is not valid JSON"; teardown; return; }
  META_COUNT=$(jq 'length' "$META_FILE" 2>/dev/null || echo 0)
  [ "$META_COUNT" -ge 1 ] || { fail "meta file is empty"; teardown; return; }

  pass "happy path ($CERT_COUNT certs, $META_COUNT meta entries)"
  teardown
}

test_missing_tsl_file() {
  setup
  export TSL_FILENAME="does-not-exist.xml"

  "$PROCESSORS_PATH/$PROCESSOR_NAME/transform.sh" > /dev/null 2>&1
  assert_no_valid_output "missing TSL file" $?
  teardown
}

test_empty_tsl_file() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  touch "$TEMP_INPUT_DIR/empty.xml"
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"
  export TSL_FILENAME="empty.xml"

  "$PROCESSORS_PATH/$PROCESSOR_NAME/transform.sh" > /dev/null 2>&1
  assert_no_valid_output "empty TSL file" $?
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_invalid_xml() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  echo "this is not xml" > "$TEMP_INPUT_DIR/invalid.xml"
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"
  export TSL_FILENAME="invalid.xml"

  "$PROCESSORS_PATH/$PROCESSOR_NAME/transform.sh" > /dev/null 2>&1
  assert_no_valid_output "invalid XML" $?
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_missing_result_dir() {
  setup
  export RESULT_DIR="/nonexistent/path"

  if "$PROCESSORS_PATH/$PROCESSOR_NAME/transform.sh" > /dev/null 2>&1; then
    fail "missing RESULT_DIR should cause failure"
  else
    pass "missing RESULT_DIR exits non-zero"
  fi
  teardown
}

test_custom_result_filenames() {
  setup
  export "$RESULT_FILENAME_VAR=$CUSTOM_P12_NAME"
  export "$META_FILENAME_VAR=$CUSTOM_META_NAME"
  "$PROCESSORS_PATH/$PROCESSOR_NAME/transform.sh" > /dev/null 2>&1

  [ -f "$RESULT_DIR/$CUSTOM_P12_NAME" ] || { fail "custom p12 filename not used"; teardown; return; }
  [ -f "$RESULT_DIR/$CUSTOM_META_NAME" ] || { fail "custom meta filename not used"; teardown; return; }
  [ ! -f "$RESULT_DIR/$DEFAULT_P12_NAME" ] || { fail "default p12 filename should not exist"; teardown; return; }
  [ ! -f "$RESULT_DIR/$DEFAULT_META_NAME" ] || { fail "default meta filename should not exist"; teardown; return; }
  openssl pkcs12 -in "$RESULT_DIR/$CUSTOM_P12_NAME" -passin "pass:$TRUSTSTORE_PASS" -nokeys -info > /dev/null 2>&1 \
    || { fail "custom p12 is not valid"; teardown; return; }
  jq empty "$RESULT_DIR/$CUSTOM_META_NAME" 2>/dev/null \
    || { fail "custom meta is not valid JSON"; teardown; return; }

  pass "custom result filenames"
  teardown
}

test_default_tsl_filename() {
  setup
  unset TSL_FILENAME
  TEMP_INPUT_DIR=$(mktemp -d)
  cp "$TEST_DIR/ECC-RSA_TSL-test.xml" "$TEMP_INPUT_DIR/ECC-RSA_TSL.xml"
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"

  OUTPUT=$("$PROCESSORS_PATH/$PROCESSOR_NAME/transform.sh" 2>&1)

  echo "$OUTPUT" | grep -q "TSL_FILENAME not defined" \
    || { fail "TSL_FILENAME default message missing"; teardown; rm -rf "$TEMP_INPUT_DIR"; return; }

  pass "default TSL_FILENAME"
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

test_missing_meta_file() {
  setup
  TEMP_INPUT_DIR=$(mktemp -d)
  echo "<empty/>" > "$TEMP_INPUT_DIR/noop.xml"
  export PROVISIONING_FILES_ROOT="$TEMP_INPUT_DIR"
  export TSL_FILENAME="noop.xml"

  "$PROCESSORS_PATH/$PROCESSOR_NAME/transform.sh" > /dev/null 2>&1
  EXIT_CODE=$?

  if [ $EXIT_CODE -ne 0 ]; then
    pass "missing meta file exits non-zero"
  else
    fail "missing meta file should exit non-zero"
  fi
  rm -rf "$TEMP_INPUT_DIR"
  teardown
}

# --- friendly name helpers ---

make_tsl() {
  local service_name="$1"
  local cert
  cert=$(xsltproc "$PROCESSORS_PATH/$PROCESSOR_NAME/$PEM_XSL_NAME" \
         "$TEST_DIR/ECC-RSA_TSL-test.xml" \
         | awk '/BEGIN CERTIFICATE/{found=1; next} /END CERTIFICATE/{exit} found{print}')
  cat <<XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<TrustServiceStatusList xmlns="http://uri.etsi.org/02231/v2#">
  <TrustServiceProviderList>
    <TrustServiceProvider>
      <TSPInformation><TSPTradeName><Name xml:lang="DE">Test TSP</Name></TSPTradeName></TSPInformation>
      <TSPServices>
        <TSPService>
          <ServiceInformation>
            <ServiceTypeIdentifier>$SERVICE_TYPE_ID</ServiceTypeIdentifier>
            <ServiceName><Name xml:lang="DE">$service_name</Name></ServiceName>
            <ServiceDigitalIdentity><DigitalId><X509Certificate>$cert</X509Certificate></DigitalId></ServiceDigitalIdentity>
            <ServiceStatus>http://uri.etsi.org/TrstSvc/Svcstatus/inaccord</ServiceStatus>
            <StatusStartingTime>2020-01-01T00:00:00Z</StatusStartingTime>
            <ServiceInformationExtensions>
              <Extension Critical="false"><ExtensionOID>$EXTENSION_OID</ExtensionOID><ExtensionValue>$EXTENSION_VALUE</ExtensionValue></Extension>
            </ServiceInformationExtensions>
          </ServiceInformation>
        </TSPService>
      </TSPServices>
    </TrustServiceProvider>
  </TrustServiceProviderList>
</TrustServiceStatusList>
XMLEOF
}

run_and_get_friendly_name() {
  local service_name="$1"
  local input_dir
  input_dir=$(mktemp -d)

  make_tsl "$service_name" > "$input_dir/fn-test.xml"

  PROVISIONING_FILES_ROOT="$input_dir" \
  TSL_FILENAME="fn-test.xml" \
  "$PROCESSORS_PATH/$PROCESSOR_NAME/transform.sh" > /dev/null 2>&1

  openssl pkcs12 -in "$RESULT_DIR/$DEFAULT_P12_NAME" -passin "pass:$TRUSTSTORE_PASS" -nokeys -info 2>&1 \
    | grep "friendlyName:" | head -1 | sed 's/.*friendlyName: //'

  rm -rf "$input_dir"
}

# --- friendly name tests ---

test_friendly_name_quotes_stripped() {
  setup
  ACTUAL=$(run_and_get_friendly_name 'CN=Test "Quoted" Name,O=Org,C=DE')
  if [ "$ACTUAL" = "CN=Test Quoted Name,O=Org,C=DE" ]; then
    pass "friendlyName: double quotes stripped"
  else
    fail "friendlyName: double quotes stripped (got '$ACTUAL')"
  fi
  teardown
}

test_friendly_name_single_quotes_stripped() {
  setup
  ACTUAL=$(run_and_get_friendly_name "CN=Test 'Quoted' Name,O=Org,C=DE")
  if [ "$ACTUAL" = "CN=Test Quoted Name,O=Org,C=DE" ]; then
    pass "friendlyName: single quotes stripped"
  else
    fail "friendlyName: single quotes stripped (got '$ACTUAL')"
  fi
  teardown
}

test_friendly_name_backslash_stripped() {
  setup
  ACTUAL=$(run_and_get_friendly_name 'CN=Test\\Name,O=Org,C=DE')
  if [ "$ACTUAL" = "CN=TestName,O=Org,C=DE" ]; then
    pass "friendlyName: backslash stripped"
  else
    fail "friendlyName: backslash stripped (got '$ACTUAL')"
  fi
  teardown
}

test_friendly_name_normal_unchanged() {
  setup
  ACTUAL=$(run_and_get_friendly_name "$NORMAL_FRIENDLY_NAME")
  if [ "$ACTUAL" = "$NORMAL_FRIENDLY_NAME" ]; then
    pass "friendlyName: normal name unchanged"
  else
    fail "friendlyName: normal name unchanged (got '$ACTUAL')"
  fi
  teardown
}

test_friendly_name_combined() {
  setup
  ACTUAL=$(run_and_get_friendly_name "CN=Test \"Quoted\" 'Name'\\\\Org,C=DE")
  if [ "$ACTUAL" = "CN=Test Quoted NameOrg,C=DE" ]; then
    pass "friendlyName: combined special chars stripped"
  else
    fail "friendlyName: combined special chars stripped (got '$ACTUAL')"
  fi
  teardown
}

# --- run ---

echo "=== $PROCESSOR_NAME ==="
test_happy_path
test_missing_tsl_file
test_empty_tsl_file
test_invalid_xml
test_missing_result_dir
test_custom_result_filenames
test_default_tsl_filename
test_missing_meta_file
test_friendly_name_quotes_stripped
test_friendly_name_single_quotes_stripped
test_friendly_name_backslash_stripped
test_friendly_name_normal_unchanged
test_friendly_name_combined

echo "  ($PASSED passed, $FAILED failed)"
exit $FAILED
