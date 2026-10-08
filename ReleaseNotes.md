<img align="right" width="250" height="47" src="docs/img/Gematik_Logo_Flag.png"/> <br/>

# ZETA Guard Provisioning Processor

## Release 1.3.2

### fixed:

- `cosign login` was called with `--registry-cacert`, a flag it does not support, so the
  provisioning container could not be fetched from a registry that requires both credentials
  and a private CA (`Error: unknown flag: --registry-cacert`). The registry CA is only needed
  by `cosign save`, which still receives it. (ANFTI2-912)


## Release 1.3.0

### added:

- option to authenticate against the provisioning container registry (non-anonymous access) via
  `PROVISIONING_CONTAINER_REGISTRY_USERNAME` and `PROVISIONING_CONTAINER_REGISTRY_TOKEN` (used for
  `cosign login` before fetching the image)
- meta file `smcb-trust-roots-meta.json` mapping each SMB CA `friendlyName` to its `tspName` and, for
  revoked CAs, the `revokedSince` date
- meta file `ocsp-signers-meta.json` mapping each OCSP signer `friendlyName` to its `tspName`
- optional `SCHEDULE_TIME` (format `HH:MM`) to keep the container resident and re-run the
  provisioning cycle daily at that time instead of exiting after a single run; invalid values are
  rejected immediately at startup. Evaluated in the timezone set via `TZ` (image now includes
  `tzdata`, so named zones like `Europe/Berlin` work; defaults to UTC if unset)
- `kubectl` added to the image, unrelated to this tool's own job — reused by `zeta-guard-helm`
  elsewhere as a minimal, non-root-by-default alternative to a generic CI tooling image

### changed:

- revoked SMB CAs of the TSL are now included in the `smcb-trust-roots.p12` truststore (certificates
  issued before the revocation date remain valid; the revocation date is provided in the meta file)
- all processors now write their result file atomically (temp file + `mv`) so a concurrent reader
  never observes a partially written file during a scheduled re-run

## Release 1.2.0

### added:

- processing of the OCSP signers of the TSL

## Release 1.0.0

### added:

- processing of `roots.json`
- option to provide the CA of the registry from which the provisioning container is fetched (for TLS) via
  `PROVISIONING_CONTAINER_REGISTRY_CA_FILE`

## Release 0.5.0

### added:

- processing of the smb CAs of the TSL
- processing of TPM CAs
- processing of policy signer certs
