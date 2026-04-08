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

if [ "$POLICY_SIGNER_CERT_FILENAME" = "" ]
then
  POLICY_SIGNER_CERT_FILENAME="$(find "$PROVISIONING_FILES_ROOT/policy-engine-bundle-keys/signers" -not -type d | head -n 1)"
  export POLICY_SIGNER_CERT_FILENAME
  echo "POLICY_SIGNER_CERT_FILENAME not defined, using  default $POLICY_SIGNER_CERT_FILENAME"
fi

if [ "$POLICY_RESULT_FILENAME" = "" ]
then
  export POLICY_RESULT_FILENAME="policy-signer.pub"
  echo "POLICY_RESULT_FILENAME not defined, using  default $POLICY_RESULT_FILENAME"
fi

RESULT_FILE="$RESULT_DIR/$POLICY_RESULT_FILENAME"

openssl x509 -in "$POLICY_SIGNER_CERT_FILENAME" -pubkey -noout -out "$RESULT_FILE"

# make sure we have something to work with
if [ -f "$RESULT_FILE" ]
then
  echo "Created file $RESULT_FILE"
else
  echo "ERROR, no result file $RESULT_FILE created!"
  exit 1
fi

