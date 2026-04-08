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

TSL_PROC_PATH="$PROCESSORS_PATH/tsl-smb"
RESULT_FILE="$RESULT_DIR/smcb-trust-roots.p12"

if [ "$TSL_FILENAME" = "" ]
then
  export TSL_FILENAME="ECC-RSA_TSL.xml"
  echo "TSL_FILENAME not defined, using  default $TSL_FILENAME"
fi

if [ "$SMB_RESULT_FILENAME" = "" ]
then
  export SMB_RESULT_FILENAME="smcb-trust-roots.p12"
  echo "SMB_RESULT_FILENAME not defined, using  default $SMB_RESULT_FILENAME"
fi

RESULT_FILE="$RESULT_DIR/$SMB_RESULT_FILENAME"

WORKDIR=$(mktemp -d)

# extract SMB certs as PEM and their friendlyNames from the TSL
xsltproc "$TSL_PROC_PATH/tsl-smb-to-pem.xsl" "$PROVISIONING_FILES_ROOT/$TSL_FILENAME" > "$WORKDIR/certsFromTsl.xpem"

# extracting names and sanitizing them of quote marks, because this somewhat untrusted input and will be expanded to a command later on
grep 'friendlyName=' "$WORKDIR/certsFromTsl.xpem" | cut -c14- | sed "s/[\"']//g"> "$WORKDIR/friendlyNames"

# setting the friendlyName can only be done via a cmd parameter for each cert. So we need to construct the openssl
# command based on the input
COMMAND="openssl pkcs12 -in \"$WORKDIR/certsFromTsl.xpem\" -passout \"pass:$TRUSTSTORE_PASS\" -nokeys -export -out \"$RESULT_FILE\""
while read -r CANAME; do
  COMMAND="$COMMAND -caname \"$CANAME\""
done < "$WORKDIR/friendlyNames"

eval "$COMMAND"

# time for cleanup
rm -rf "$WORKDIR"

# make sure we have something to work with
if [ -f "$RESULT_FILE" ]
then
  echo "Created file $RESULT_FILE"
else
  echo "ERROR, no result file $RESULT_FILE created!"
  exit 1
fi

