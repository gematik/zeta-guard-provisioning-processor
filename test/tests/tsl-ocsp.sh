#!/usr/bin/env bash

PROCESSOR_NAME="tsl-ocsp"
DEFAULT_P12_NAME="ocsp-signers.p12"
DEFAULT_META_NAME="ocsp-signers-meta.json"
RESULT_FILENAME_VAR="OCSP_RESULT_FILENAME"
META_FILENAME_VAR="OCSP_META_FILENAME"
CUSTOM_P12_NAME="custom-ocsp.p12"
CUSTOM_META_NAME="custom-ocsp-meta.json"
PEM_XSL_NAME="tsl-ocsp-to-pem.xsl"
SERVICE_TYPE_ID="http://uri.etsi.org/TrstSvc/Svctype/Certstatus/OCSP"
EXTENSION_OID="1.2.276.0.76.4.124"
EXTENSION_VALUE="oid_tsl_placeholder"
NORMAL_FRIENDLY_NAME="CN=Komp-CA50 OCSP-Signer1 TEST-ONLY,O=gematik GmbH,C=DE"

source "$(cd "$(dirname "$0")/../lib" && pwd)/tsl-transform.sh"
