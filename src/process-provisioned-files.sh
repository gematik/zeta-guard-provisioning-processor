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

"$TOOLS_PATH"/fetch-provisioning-container.sh

if [ "$RESULT_DIR" = "" ]
then
  echo "ERROR: RESULT_DIR not defined"
  exit 1
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
  echo "tsl smb transformer is disabled. If you need it, enable it via PROCESSORS_TSL_SMB_ENABLED=true"
fi
echo "............................"
echo "end of smb tsl transformer"
echo "............................"

echo "=============+==============="
echo "start of ocsp tsl transformer"
echo "==============+=============="
if [ "$PROCESSORS_TSL_OCSP_ENABLED" = "true" ]
then
  "$PROCESSORS_PATH"/tsl-ocsp/transform.sh
else
  echo "tsl ocsp transformer is disabled. If you need it, enable it via PROCESSORS_TSL_OCSP_ENABLED=true"
fi
echo "............................"
echo "end of ocsp tsl transformer"
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


echo "============================"
echo "start of roots-json transformer"
echo "============================"
if [ "$PROCESSORS_ROOTS_JSON_ENABLED" = "true" ]
then
  "$PROCESSORS_PATH"/roots-json/transform.sh
else
  echo "roots-json transformer is disabled. If you need it, enable it via PROCESSORS_ROOTS_JSON_ENABLED=true"
fi
echo "............................"
echo "end of roots-json transformer"
echo "............................"

rm -rf "$PROVISIONING_FILES_ROOT"

if [ -n "$SCHEDULE_TIME" ]
then
  case "$SCHEDULE_TIME" in
    [01][0-9]:[0-5][0-9]|2[0-3]:[0-5][0-9]) ;;
    *)
      echo "ERROR: SCHEDULE_TIME must be in HH:MM format (e.g. 03:00), got: $SCHEDULE_TIME"
      exit 1
      ;;
  esac

  echo "SCHEDULE_TIME=$SCHEDULE_TIME: staying resident, re-running daily at that time"
  while true
  do
    TODAY=$(date +%Y-%m-%d)
    NOW_EPOCH=$(date +%s)
    NEXT_EPOCH=$(date -d "$TODAY $SCHEDULE_TIME" +%s)
    if [ "$NEXT_EPOCH" -le "$NOW_EPOCH" ]
    then
      TOMORROW=$(date -d "@$(( NOW_EPOCH + 86400 ))" +%Y-%m-%d)
      NEXT_EPOCH=$(date -d "$TOMORROW $SCHEDULE_TIME" +%s)
    fi
    SLEEP_SECONDS=$(( NEXT_EPOCH - NOW_EPOCH ))
    echo "Next provisioning run at $(date -d "@$NEXT_EPOCH"), sleeping ${SLEEP_SECONDS}s"
    sleep "$SLEEP_SECONDS"

    echo "Re-running scheduled provisioning cycle"
    if ! SCHEDULE_TIME="" "$0"; then
      echo "WARNING: scheduled provisioning run failed, will retry at next scheduled time"
    fi
  done
fi