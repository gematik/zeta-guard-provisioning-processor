#!/usr/bin/env bash
#
# /*-
#  * #%L
#  * provisioning-processor
#  * %%
#  * (C) tech@Spree GmbH, 2026, licensed for gematik GmbH
#  * %%
#  * Licensed under the Apache License, Version 2.0 (the "License");
#  * you may not use this file except in compliance with the License.
#  * You may obtain a copy of the License at
#  *
#  *     http://www.apache.org/licenses/LICENSE-2.0
#  *
#  * Unless required by applicable law or agreed to in writing, software
#  * distributed under the License is distributed on an "AS IS" BASIS,
#  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  * See the License for the specific language governing permissions and
#  * limitations under the License.
#  *
#  * *******
#  *
#  * For additional notes and disclaimer from gematik and in case of changes by gematik find details in the "Readme" file.
#  * #L%
#  */
#
set -e

if [ "$PROVISIONING_FILES_ROOT" = "" ]
then
  PROVISIONING_FILES_ROOT=$(mktemp -d)
  export PROVISIONING_FILES_ROOT
  echo "PROVISIONING_FILES_ROOT not defined, using $PROVISIONING_FILES_ROOT"
else
  echo "Using PROVISIONING_FILES_ROOT as defined: $PROVISIONING_FILES_ROOT"
fi

"$TOOLS_PATH"/fetch-proviosining-container.sh

if [ "$RESULT_DIR" = "" ]
then
  echo "ERROR: RESULT_DIR not defined"
else
  echo "Using RESULT_DIR as defined: $RESULT_DIR"
fi

if [ "$TRUSTSTORE_PASS" = "" ]
then
  export TRUSTSTORE_PASS="no_secret_for_trust_only"
  echo "TRUSTSTORE_PASS not defined, using the default"
else
  echo "Using TRUSTSTORE_PASS as defined per env variable."
fi

echo "============================"
echo "start of smb tsl transformer"
echo "============================"
if [ "$PROCESSORS_TSL_SMB_ENABLED" = "true" ]
then
  "$PROCESSORS_PATH"/tsl-smb/transform.sh
else
  echo "tsl transformer is disabled. If you need it, enable it via PROCESSORS_TSL_SMB_ENABLED=true"
fi
echo "............................"
echo "end of smb tsl transformer"
echo "............................"


echo "============================"
echo "start of tpm transformer"
echo "============================"
if [ "$PROCESSORS_TPM_ENABLED" = "true" ]
then
  "$PROCESSORS_PATH"/tpm/transform.sh
else
  echo "tpm transformer is disabled. If you need it, enable it via PROCESSORS_TPM_ENABLED=true"
fi
echo "............................"
echo "end of tpm transformer"
echo "............................"


echo "============================"
echo "start of policy-signer transformer"
echo "============================"
if [ "$PROCESSORS_POLICY_SIGNER_ENABLED" = "true" ]
then
  "$PROCESSORS_PATH"/policy-signer/transform.sh
else
  echo "policy-signer transformer is disabled. If you need it, enable it via PROCESSORS_POLICY_SIGNER_ENABLED=true"
fi
echo "............................"
echo "end of policy-signer transformer"
echo "............................"

rm -rf "$PROVISIONING_FILES_ROOT"