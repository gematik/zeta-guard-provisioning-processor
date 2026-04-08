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

if [ "$TPM_CAB_FILENAME" = "" ]
then
  export TPM_CAB_FILENAME="TrustedTpm.cab"
  echo "TPM_CAB_FILENAME not defined, using  default $TPM_CAB_FILENAME"
fi

if [ "$TPM_RESULT_FILENAME" = "" ]
then
  export TPM_RESULT_FILENAME="tpm-trust-roots.p12"
  echo "TPM_RESULT_FILENAME not defined, using  default $TPM_RESULT_FILENAME"
fi

RESULT_FILE="$RESULT_DIR/$TPM_RESULT_FILENAME"

CABDIR=$(mktemp -d)
cabextract -q -d "$CABDIR" "$PROVISIONING_FILES_ROOT/$TPM_CAB_FILENAME"

WORKDIR=$(mktemp -d)


TEMP_PEM_FILE="$WORKDIR/temp.pem"
touch "$TEMP_PEM_FILE"

echo "Wrapping the certs up into a temporary PEM file."
echo "Expecting this to fail for the following files, because they have defective ASN1 encoding. But there is a fixed certificate file for each one of these:"
# that's also a reason why we don't have "set -e" for this file
echo "STMicro/IntermediateCA/STM TPM ECC Intermediate CA 01.crt with a fixed certificate in STMicro/IntermediateCA/STM TPM ECC Intermediate CA 01_2.crt"
echo "STMicro/IntermediateCA/STM TPM EK Intermediate CA 01.crt with a fixed certificate in STMicro/IntermediateCA/STM TPM EK Intermediate CA 01_2.crt"
echo "STMicro/IntermediateCA/STM TPM EK Intermediate CA 02.crt with a fixed certificate in STMicro/IntermediateCA/STM TPM EK Intermediate CA 02_2.crt"
echo "STMicro/IntermediateCA/STM TPM EK Intermediate CA 03.crt with a fixed certificate in STMicro/IntermediateCA/STM TPM EK Intermediate CA 03_2.crt"
echo "STMicro/IntermediateCA/STM TPM EK Intermediate CA 04.crt with a fixed certificate in STMicro/IntermediateCA/STM TPM EK Intermediate CA 04_2.crt"
echo "STMicro/IntermediateCA/STM TPM EK Intermediate CA 05.crt with a fixed certificate in STMicro/IntermediateCA/STM TPM EK Intermediate CA 05_2.crt"

# This tpm cab file does not really use file endings consistently. So we have to guess the format (PEM or DER) by
# looking at the content (i.e. grepping for "BEGIN CERTIFICATE" but only in files *.der, *.cer and *.crt because
# there are also scripts and stuff like that in this file.

# cat all pem encoded certs into the temp pem file
while IFS= read -r PEM_CERT
do
  cat "$PEM_CERT" >> "$TEMP_PEM_FILE"
done < <(grep -RIl "BEGIN CERTIFICATE" "$CABDIR" | grep -E '\.(der|cer|crt)$')

# read all DER encoded certs and cat them as pem into the temp pem file
while IFS= read -r DER_CERT
do
  openssl x509 -inform DER -in "$DER_CERT" >> "$TEMP_PEM_FILE"
done < <(grep -RL "BEGIN CERTIFICATE" "$CABDIR" | grep -E '\.(der|cer|crt)$')

# reencode the temp pem file into a pkcs12 truststore
openssl pkcs12 -in "$TEMP_PEM_FILE" -passout "pass:$TRUSTSTORE_PASS" -nokeys -export -out "$RESULT_FILE"

# time for cleanup
rm -rf "$CABDIR"
rm -rf "$WORKDIR"

# make sure we have something to work with
if [ -f "$RESULT_FILE" ]
then
  echo "Created file $RESULT_FILE"
else
  echo "ERROR, no result file $RESULT_FILE created!"
  exit 1
fi

