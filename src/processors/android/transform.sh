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

CA_ROOT="google-root-ca"
CURRENT="$(cd "$(dirname "$0")" && pwd)"
STATUS_URL="https://android.googleapis.com:443/attestation/status"

if [ "$ANDROID_ROOT_CERT_FILENAME" = "" ] ; then
  ANDROID_ROOT_CERT_FILENAME="$PROVISIONING_FILES_ROOT/android-roots/roots.json"
  export ANDROID_ROOT_CERT_FILENAME
  echo "ℹ️ ANDROID_ROOT_CERT_FILENAME not defined, using default $ANDROID_ROOT_CERT_FILENAME"
fi

if [ "$ANDROID_ROOT_STATUS_FILENAME" = "" ] ; then
  ANDROID_ROOT_STATUS_FILENAME="$PROVISIONING_FILES_ROOT/android-roots/status.json"
  export ANDROID_ROOT_STATUS_FILENAME
  echo "ℹ️ ANDROID_ROOT_STATUS_FILENAME not defined, using default $ANDROID_ROOT_STATUS_FILENAME"
fi

if [ ! -f "$ANDROID_ROOT_CERT_FILENAME" ]
then
  echo "💣 ERROR: $ANDROID_ROOT_CERT_FILENAME does not exist"
  exit 1
fi

if [ "$ANDROID_ROOT_RESULT_FILENAME" = "" ]
then
  export ANDROID_ROOT_RESULT_FILENAME="google-trust-roots.p12"
  echo "ℹ️ ANDROID_ROOT_RESULT_FILENAME not defined, using default $ANDROID_ROOT_RESULT_FILENAME"
fi

if [ "$ANDROID_ROOT_RESULT_STATUS_FILENAME" = "" ]
then
  export ANDROID_ROOT_RESULT_STATUS_FILENAME="google-certificate-status.json"
  echo "ℹ️ ANDROID_ROOT_RESULT_STATUS_FILENAME not defined, using default $ANDROID_ROOT_RESULT_STATUS_FILENAME"
fi

RESULT_FILE="$RESULT_DIR/$ANDROID_ROOT_RESULT_FILENAME"
TMP_RESULT_FILE="$RESULT_DIR/$ANDROID_ROOT_RESULT_FILENAME.tmp.$$"
trap 'rm -f "$TMP_RESULT_FILE"' EXIT

echo "ℹ️ Extracting PEM files from JSON"

# --- Count certificates ---
count="$(jq length < "$ANDROID_ROOT_CERT_FILENAME")"
echo "ℹ️ Found $count certificate(s)."

# --- Extract each certificate ---
for i in $(seq 0 $((count - 1))); do
    cert_index=$((i + 1))
    outfile="$RESULT_DIR/google_root_ca_${cert_index}.pem"

    # jq -r decodes the JSON string and outputs the raw PEM content.
    # The '.[N]' index retrieves the N-th array element.
    jq -r --argjson idx "$i" '.[$idx]' < "$ANDROID_ROOT_CERT_FILENAME" > "$outfile"

    # Sanity check: ensure the file actually contains a PEM certificate
    if ! grep -q "BEGIN CERTIFICATE" "$outfile"; then
        echo "⚠️ WARNING: $outfile does not look like a PEM certificate." >&2
    fi

    echo "Wrote $outfile"
done

cat "$RESULT_DIR"/google_root_ca_*.pem | openssl pkcs12 -export -nokeys -jdktrust anyExtendedKeyUsage -caname "$CA_ROOT"-RSA -caname "$CA_ROOT"-ECDSA -out "$TMP_RESULT_FILE" -password "pass:$TRUSTSTORE_PASS"

# make sure we have something to work with, then publish atomically
if [ -f "$TMP_RESULT_FILE" ]
then
  mv -f "$TMP_RESULT_FILE" "$RESULT_FILE"
  echo "☑️ Created file $RESULT_FILE"
else
  echo "💣 ERROR, no result file $RESULT_FILE created!"
  exit 1
fi

if [ ! -f "$ANDROID_ROOT_STATUS_FILENAME" ]
then
  echo "🩹 Executing workaround by downloading status file from $CURRENT"

  TMP_STATUS_FILE="$RESULT_DIR/status.json"

  curl -fsSL "$STATUS_URL" -o "$TMP_STATUS_FILE"

  ANDROID_ROOT_STATUS_FILENAME="$TMP_STATUS_FILE"
fi

if [ ! -f "$ANDROID_ROOT_STATUS_FILENAME" ]
then
  echo "💣 ERROR: $ANDROID_ROOT_STATUS_FILENAME does not exist"
  exit 1
else
  cp "$ANDROID_ROOT_STATUS_FILENAME" "$RESULT_DIR/$ANDROID_ROOT_RESULT_STATUS_FILENAME"
fi

if [ -f "$RESULT_DIR/$ANDROID_ROOT_RESULT_STATUS_FILENAME" ]
then
  echo "☑️ Created file $RESULT_DIR/$ANDROID_ROOT_RESULT_STATUS_FILENAME"
else
  echo "💣 ERROR, no result file $RESULT_DIR/$ANDROID_ROOT_RESULT_STATUS_FILENAME created!"
  exit 1
fi
