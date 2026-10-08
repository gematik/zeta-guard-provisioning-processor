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

if [ "$PROVISIONING_CONTAINER_NAME" = "" ]
then
  export PROVISIONING_CONTAINER_NAME="europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-provisioning/zeta-guard-provisioning:latest"
  echo "PROVISIONING_CONTAINER_NAME not defined, using default $PROVISIONING_CONTAINER_NAME"
else
  echo "Using PROVISIONING_CONTAINER_NAME as defined: $PROVISIONING_CONTAINER_NAME"
fi

if [ "$TRUST_CERTCHAIN_FILE" = "" ]
then
  echo "ERROR: TRUST_CERTCHAIN_FILE not defined"
  exit 1
else
  echo "Using TRUST_CERTCHAIN_FILE as defined: $TRUST_CERTCHAIN_FILE"
fi

if [ -n "$PROVISIONING_CONTAINER_REGISTRY_CA_FILE" ]
then
  echo "Using PROVISIONING_CONTAINER_REGISTRY_CA_FILE as defined: $PROVISIONING_CONTAINER_REGISTRY_CA_FILE"
  export REGISTRY_CA_FILE="$PROVISIONING_CONTAINER_REGISTRY_CA_FILE"
else
  echo "PROVISIONING_CONTAINER_REGISTRY_CA_FILE not defined. Using container defaults."
  export REGISTRY_CA_FILE=""
fi

CONTAINER_DOWNLOAD_DIR=$(mktemp -d)
mkdir -p "$PROVISIONING_FILES_ROOT"

if [ -n "$PROVISIONING_CONTAINER_REGISTRY_USERNAME" ] || [ -n "$PROVISIONING_CONTAINER_REGISTRY_TOKEN" ]
then
  if [ -z "$PROVISIONING_CONTAINER_REGISTRY_USERNAME" ] || [ -z "$PROVISIONING_CONTAINER_REGISTRY_TOKEN" ]
  then
    echo "ERROR: PROVISIONING_CONTAINER_REGISTRY_USERNAME and PROVISIONING_CONTAINER_REGISTRY_TOKEN must both be set"
    exit 1
  fi

  # The registry host is the part of the image reference before the first slash.
  REGISTRY_HOST="${PROVISIONING_CONTAINER_NAME%%/*}"

  # cosign login stores the credentials in a Docker config that cosign save reads
  # afterwards. Point DOCKER_CONFIG at a writable directory (the container runs as
  # UID 1000, so $HOME/.docker is not guaranteed to be writable).
  export DOCKER_CONFIG="$CONTAINER_DOWNLOAD_DIR/.docker"
  mkdir -p "$DOCKER_CONFIG"

  # No registry CA here: cosign login has no registry TLS flags and makes no network
  # call, it only writes the credentials to $DOCKER_CONFIG. The TLS connection to the
  # registry happens in cosign save below, which does accept --registry-cacert.
  echo "Logging in to registry $REGISTRY_HOST as $PROVISIONING_CONTAINER_REGISTRY_USERNAME"
  printf '%s' "$PROVISIONING_CONTAINER_REGISTRY_TOKEN" | cosign login "$REGISTRY_HOST" \
      --username "$PROVISIONING_CONTAINER_REGISTRY_USERNAME" \
      --password-stdin
else
  echo "PROVISIONING_CONTAINER_REGISTRY_USERNAME/_TOKEN not defined. Using anonymous registry access."
fi

echo "Downloading image: $PROVISIONING_CONTAINER_NAME"
cosign save \
    --registry-cacert="$REGISTRY_CA_FILE" \
    --dir "$CONTAINER_DOWNLOAD_DIR" \
    "$PROVISIONING_CONTAINER_NAME"

echo "Verifying image signature"
cosign verify \
    --certificate-chain "$TRUST_CERTCHAIN_FILE" \
    --certificate-identity "software-development@gematik.de" \
    --certificate-oidc-issuer-regexp ".*" \
    --insecure-ignore-tlog \
    --insecure-ignore-sct \
    --local-image "$CONTAINER_DOWNLOAD_DIR"

echo "Extracting rootfs layers..."
MANIFEST_DIGEST=$(jq -r '.manifests[] | select(.annotations.kind == "dev.cosignproject.cosign/image") | .digest' "$CONTAINER_DOWNLOAD_DIR/index.json" | cut -d: -f2)
MANIFEST="$CONTAINER_DOWNLOAD_DIR/blobs/sha256/$MANIFEST_DIGEST"

jq -r '.layers[].digest' "$MANIFEST" | while read -r LAYER_DIGEST; do
  BLOB="$CONTAINER_DOWNLOAD_DIR/blobs/sha256/$(echo "$LAYER_DIGEST" | cut -d: -f2)"
  tar -xzf "$BLOB" -C "$PROVISIONING_FILES_ROOT"
done

rm -rf "$CONTAINER_DOWNLOAD_DIR"
echo "Image rootfs extracted to $PROVISIONING_FILES_ROOT"
