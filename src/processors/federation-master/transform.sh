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

if [ "$FEDERATION_MASTER_FILENAME" = "" ]
then
  export FEDERATION_MASTER_FILENAME="federation-master.yaml"
  echo "FEDERATION_MASTER_FILENAME not defined, using default $FEDERATION_MASTER_FILENAME"
fi

if [ "$FEDERATION_MASTER_RESULT_FILENAME" = "" ]
then
  export FEDERATION_MASTER_RESULT_FILENAME="federation-master.json"
  echo "FEDERATION_MASTER_RESULT_FILENAME not defined, using default $FEDERATION_MASTER_RESULT_FILENAME"
fi

if [ -z "$FEDERATION_MASTER_ENVIRONMENT" ]
then
  echo "ERROR: FEDERATION_MASTER_ENVIRONMENT not defined"
  exit 1
fi

INPUT_FILE="$PROVISIONING_FILES_ROOT/$FEDERATION_MASTER_FILENAME"

if [ ! -f "$INPUT_FILE" ]
then
  echo "ERROR: $INPUT_FILE does not exist"
  exit 1
fi

FEDMASTER_URL_VALUE=$(yq -r ".ti_federation_master[] | select(.environment == \"$FEDERATION_MASTER_ENVIRONMENT\") | .entity_statement_uri" "$INPUT_FILE")

MATCH_COUNT=$(echo "$FEDMASTER_URL_VALUE" | wc -l)
if [ "$MATCH_COUNT" -ne 1 ] || [ -z "$FEDMASTER_URL_VALUE" ]
then
  echo "ERROR: expected exactly one entry for environment '$FEDERATION_MASTER_ENVIRONMENT', got $MATCH_COUNT"
  exit 1
fi

if [ "$DEV_MODE" = "true" ] && [ -n "$FEDMASTER_URL" ]
then
  echo "DEV_MODE active: overriding fedmasterUrl with FEDMASTER_URL"
  FEDMASTER_URL_VALUE="$FEDMASTER_URL"
  if ! echo "$FEDMASTER_URL_VALUE" | grep -qE '^https?://[^/]+'
  then
    echo "ERROR: fedmasterUrl must be an absolute HTTP(S) URL, got: '$FEDMASTER_URL_VALUE'"
    exit 1
  fi
else
  if ! echo "$FEDMASTER_URL_VALUE" | grep -qE '^https://[^/]+'
  then
    echo "ERROR: fedmasterUrl must be an absolute HTTPS URL, got: '$FEDMASTER_URL_VALUE'"
    exit 1
  fi
fi

# Keycloak appends /.well-known/openid-federation itself
FEDMASTER_URL_VALUE="${FEDMASTER_URL_VALUE%/.well-known/openid-federation}"

RESULT_FILE="$RESULT_DIR/$FEDERATION_MASTER_RESULT_FILENAME"
TMP_RESULT_FILE="$RESULT_DIR/.$FEDERATION_MASTER_RESULT_FILENAME.tmp.$$"
trap 'rm -f "$TMP_RESULT_FILE"' EXIT

jq -n --arg url "$FEDMASTER_URL_VALUE" '{"fedmasterUrl": $url}' > "$TMP_RESULT_FILE"

# make sure we have something to work with, then publish atomically
if [ -f "$TMP_RESULT_FILE" ]
then
  mv -f "$TMP_RESULT_FILE" "$RESULT_FILE"
  echo "Created file $RESULT_FILE"
else
  echo "ERROR, no result file $RESULT_FILE created!"
  exit 1
fi
