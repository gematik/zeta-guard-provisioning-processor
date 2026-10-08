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

TSL_PROC_PATH="$PROCESSORS_PATH/tsl-ocsp"
RESULT_FILE="$RESULT_DIR/ocsp-signers.p12"

if [ "$TSL_FILENAME" = "" ]
then
  export TSL_FILENAME="ECC-RSA_TSL.xml"
  echo "TSL_FILENAME not defined, using  default $TSL_FILENAME"
fi

if [ "$OCSP_RESULT_FILENAME" = "" ]
then
  export OCSP_RESULT_FILENAME="ocsp-signers.p12"
  echo "OCSP_RESULT_FILENAME not defined, using  default $OCSP_RESULT_FILENAME"
fi

if [ "$OCSP_META_FILENAME" = "" ]
then
  export OCSP_META_FILENAME="ocsp-signers-meta.json"
  echo "OCSP_META_FILENAME not defined, using default $OCSP_META_FILENAME"
fi

RESULT_FILE="$RESULT_DIR/$OCSP_RESULT_FILENAME"
META_FILE="$RESULT_DIR/$OCSP_META_FILENAME"
TMP_RESULT_FILE="$RESULT_DIR/.$OCSP_RESULT_FILENAME.tmp.$$"
TMP_META_FILE="$RESULT_DIR/.$OCSP_META_FILENAME.tmp.$$"
trap 'rm -f "$TMP_RESULT_FILE" "$TMP_META_FILE"' EXIT

WORKDIR=$(mktemp -d)

# extract SMB certs as PEM and their friendlyNames from the TSL
xsltproc "$TSL_PROC_PATH/tsl-ocsp-to-pem.xsl" "$PROVISIONING_FILES_ROOT/$TSL_FILENAME" > "$WORKDIR/certsFromTsl.xpem"

# extract metadata (TSPTradeName) as JSON
xsltproc "$TSL_PROC_PATH/tsl-ocsp-to-meta.xsl" "$PROVISIONING_FILES_ROOT/$TSL_FILENAME" > "$TMP_META_FILE"

# extract names (quote-stripping is handled in the XSLT)
grep 'friendlyName=' "$WORKDIR/certsFromTsl.xpem" | cut -c14- > "$WORKDIR/friendlyNames"

# setting the friendlyName can only be done via a cmd parameter for each cert. So we need to construct the openssl
# command based on the input
COMMAND="openssl pkcs12 -in \"$WORKDIR/certsFromTsl.xpem\" -passout \"pass:$TRUSTSTORE_PASS\" -nokeys -export -out \"$TMP_RESULT_FILE\""
while read -r CANAME; do
  COMMAND="$COMMAND -caname \"$CANAME\""
done < "$WORKDIR/friendlyNames"

eval "$COMMAND"

# time for cleanup
rm -rf "$WORKDIR"

# make sure we have something to work with, then publish atomically
if [ -f "$TMP_RESULT_FILE" ]
then
  mv -f "$TMP_RESULT_FILE" "$RESULT_FILE"
  echo "Created file $RESULT_FILE"
else
  echo "ERROR, no result file $RESULT_FILE created!"
  exit 1
fi

if [ -f "$TMP_META_FILE" ]
then
  mv -f "$TMP_META_FILE" "$META_FILE"
  echo "Created file $META_FILE"
else
  echo "ERROR, no metadata file $META_FILE created!"
  exit 1
fi
