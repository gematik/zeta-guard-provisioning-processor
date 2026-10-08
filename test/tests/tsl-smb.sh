#!/usr/bin/env bash

PROCESSOR_NAME="tsl-smb"
DEFAULT_P12_NAME="smcb-trust-roots.p12"
DEFAULT_META_NAME="smcb-trust-roots-meta.json"
RESULT_FILENAME_VAR="SMB_RESULT_FILENAME"
META_FILENAME_VAR="SMB_META_FILENAME"
CUSTOM_P12_NAME="custom-smb.p12"
CUSTOM_META_NAME="custom-smb-meta.json"
PEM_XSL_NAME="tsl-smb-to-pem.xsl"
SERVICE_TYPE_ID="http://uri.etsi.org/TrstSvc/Svctype/CA/PKC"
EXTENSION_OID="1.2.276.0.76.4.77"
EXTENSION_VALUE="oid_smc_b_aut"
NORMAL_FRIENDLY_NAME="CN=GEM.SMCB-CA20 TEST-ONLY,OU=Test-CA,O=gematik GmbH,C=DE"

source "$(cd "$(dirname "$0")/../lib" && pwd)/tsl-transform.sh"
