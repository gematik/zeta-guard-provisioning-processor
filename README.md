<img align="right" width="250" height="47" src="docs/img/Gematik_Logo_Flag.png"/> <br/>

# ZETA Guard Provisioning Processor

Bereitet die Daten des Provisioning Container für die einzelnen Dienste des ZETA Guard auf.

## Benutzung

Der Container benötigt drei Volumes:

1. Ein Volume (nur Lesezugriff) mit dem Inhalt des Provisioning Containers
2. Ein schreibbares Volume zur Ablage der Verarbeitungsergebnisse
3. Unter `/tmp` ein schreibbares Volume für temporär zur Verarbeitung benötigte Daten

Die Volumes werden per Umgebungsvariablen eingestellt (s. u.).

Darüber hinaus ist es möglich, nur die benötigten Teile des Provisioning Containers, zu verarbeiten.
Es gibt für die unterschiedlichen Teile jeweils "processors". Diese müssen bei Bedarf explizit
via Umgebungsvariable eingeschaltet werden.

Es gibt folgende processors:

- TSL SMB: Extrahiert die SMB CAs aus dem TSL Dokument und legt sie in einem PKCS12 Truststore ab.
    - legt eine Ergebnisdatei `smcb-trust-roots.p12` an
- TPM: Konvertiert die kanonische .cab Datei in einen PKCS12 Truststore.
    - legt eine Ergebnisdatei `tpm-trust-roots.p12` an
- Policy Signer: Extrahiert die von der Policy Engine zu verwendenden Bundlesignaturschlüssel
- Roots.json: Erzeugt die `roots.json`

### Umgebungsvariablen

| Kategorie | Variable                                  | default                                                                                             | Beschreibung                                                                                                                                                                                                                     | Pflichtfeld |
|-----------|-------------------------------------------|-----------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| Allgemein | `RESULT_DIR`                              |                                                                                                     | Ort an den die Verarbeiteten Ergebnisse gelegt werden sollen                                                                                                                                                                     | Ja          |
| Allgemein | `TRUST_CERTCHAIN_FILE`                    |                                                                                                     | Dateiname der PEM Datei mit der Zertifikatskette für die Signatur des Provisioning Containers. Diese Datei muss dem Container zur Verfügung gestellt werden.                                                                     | Ja          |
| Allgemein | `PROVISIONING_CONTAINER_NAME`             | `europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-provisioning/zeta-guard-provisioning:latest` | Name des Provisioning Containers.                                                                                                                                                                                                | Nein        |
| Allgemein | `PROVISIONING_CONTAINER_REGISTRY_CA_FILE` |                                                                                                     | Pfad zu einer PEM-Datei mit dem CA-Zertifikat, das das TLS-Zertifikat der Registry ausgestellt hat. Empfohlene Variante, da große Zertifikatsketten als Datei übergeben werden ohne das Kernel-Limit `ARG_MAX` zu überschreiten. | Nein        |
| Allgemein | `PROVISIONING_FILES_ROOT`                 | Der Container erstellt ein Verzeichnis via `mktemp -d`                                              | Ort an dem der Inhalt des Provisioning Container liegt                                                                                                                                                                           | Nein        |
| Allgemein | `TRUSTSTORE_PASS`                         | `no_secret_for_trust_only`                                                                          | Passwort für Truststores                                                                                                                                                                                                         | Nein        |
| TSL SMB   | `PROCESSORS_TSL_SMB_ENABLED`              |                                                                                                     | Falls die SMB CAs aus der TSL aufbereitet werden sollen, muss diese Variable `true` sein.                                                                                                                                        | Nein        |
| TSL SMB   | `TSL_FILENAME`                            | `ECC-RSA_TSL.xml`                                                                                   | Name der TSL Datei im Provisioning Container.                                                                                                                                                                                    | Nein        |
| TSL SMB   | `SMB_RESULT_FILENAME`                     | `smcb-trust-roots.p12`                                                                              | Name der Datei mit dem Verarbeitungsergebnis des TSL SMB processor (PKCS12 Datei)                                                                                                                                                | Nein        |
| TPM       | `PROCESSORS_TPM_ENABLED`                  |                                                                                                     | Falls die TPM CAs aus der TSL aufbereitet werden sollen, muss diese Variable `true` sein.                                                                                                                                        | Nein        |
| TPM       | `TPM_CAB_FILENAME`                        | `TrustedTpm.cab`                                                                                    | Name der .cab-Datei mit den TPM Zertifikaten im Provisioning Container.                                                                                                                                                          | Nein        |
| TPM       | `TPM_RESULT_FILENAME`                     | `tpm-trust-roots.p12`                                                                               | Name der Datei mit dem Verarbeitungsergebnis des TPM processor (PKCS12 Datei)                                                                                                                                                    | Nein        |
| Policy    | `PROCESSORS_POLICY_SIGNER_ENABLED`        |                                                                                                     | Falls das Policy Signer Zertifikat aufbereitet werden soll, muss diese Variable `true` sein.                                                                                                                                     | Nein        |
| Policy    | `POLICY_SIGNER_CERT_FILENAME`             | `find "$PROVISIONING_FILES_ROOT/policy-engine-bundle-keys/signers" -not -type d \| head -n 1)`      | Name des end entity Zertifikatsdatei des Policy Signer Zertifikats.                                                                                                                                                              | Nein        |
| Policy    | `POLICY_RESULT_FILENAME`                  | `policy-signer.pub`                                                                                 | Name der Datei mit dem Verarbeitungsergebnis des Policy processor (PEM encoded public key)                                                                                                                                       | Nein        |
| Policy    | `PROCESSORS_ROOTS_JSON_ENABLED`           |                                                                                                     | Falls das `roots.json` bereitgestellt werden soll, muss diese Variable `true` sein.                                                                                                                                              | Nein        |

## Kompilieren

Es muss lediglich der OCI container via docker gebaut werden:

```
docker buildx build -t provisionsing-container .
```

## License

(C) tech@Spree GmbH, 2026, licensed for gematik GmbH

Apache License, Version 2.0

See the [LICENSE](./LICENSE) for the specific language governing permissions and limitations under the License

## Additional Notes and Disclaimer from gematik GmbH

1. Copyright notice: Each published work result is accompanied by an explicit statement of the license conditions for use. These are regularly typical conditions in connection with open source or free software. Programs described/provided/linked here are free software, unless otherwise stated.
2. Permission notice: Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
    1. The copyright notice (Item 1) and the permission notice (Item 2) shall be included in all copies or substantial portions of the Software.
    2. The software is provided "as is" without warranty of any kind, either express or implied, including, but not limited to, the warranties of fitness for a particular purpose, merchantability, and/or non-infringement. The authors or copyright holders shall not be liable in any manner whatsoever for any damages or other claims arising from, out of or in connection with the software or the use or other dealings with the software, whether in an action of contract, tort, or otherwise.
    3. We take open source license compliance very seriously. We are always striving to achieve compliance at all times and to improve our processes. If you find any issues or have any suggestions or comments, or if you see any other ways in which we can improve, please reach out to: ospo@gematik.de
3. Please note: Parts of this code may have been generated using AI-supported technology. Please take this into account, especially when troubleshooting, for security analyses and possible adjustments.
