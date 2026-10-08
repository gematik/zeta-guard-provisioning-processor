<img align="right" width="250" height="47" src="docs/img/Gematik_Logo_Flag.png"/> <br/>

# ZETA Guard Provisioning Processor

Bereitet die Daten des Provisioning Container für die einzelnen Dienste des ZETA Guard auf.

Das Image enthält außerdem `kubectl`. Das hat mit der eigentlichen Aufgabe hier nichts zu
tun — es wird von `zeta-guard-helm` an anderer Stelle wiederverwendet (z. B. für den
OPA-Rollout-Restart-CronJob), um kein separates, ungehärtetes Tooling-Image zu benötigen.

## Benutzung

Der Container benötigt drei Volumes:

1. Ein Volume (nur Lesezugriff) mit dem Inhalt des Provisioning Containers
2. Ein schreibbares Volume zur Ablage der Verarbeitungsergebnisse
3. Unter `/tmp` ein schreibbares Volume für temporär zur Verarbeitung benötigte Daten

Die Volumes werden per Umgebungsvariablen eingestellt (s. u.).

Darüber hinaus ist es möglich, nur die benötigten Teile des Provisioning Containers, zu verarbeiten.
Es gibt für die unterschiedlichen Teile jeweils "processors". Diese müssen bei Bedarf explizit
via Umgebungsvariable eingeschaltet werden.

Standardmäßig läuft der Container einmalig durch und beendet sich danach. Wird `SCHEDULE_TIME`
gesetzt, bleibt der Container stattdessen resident und wiederholt den Verarbeitungslauf täglich
zur angegebenen Uhrzeit (Zeitzone per `TZ`-Umgebungsvariable, standardmäßig UTC, siehe Tabelle
unten) ohne dass der Container neu gestartet werden muss. Beispiel für einen täglichen Lauf um
3 Uhr deutscher Zeit: `SCHEDULE_TIME=03:00` zusammen mit `TZ=Europe/Berlin`.

Es gibt folgende processors:

- TSL SMB: Extrahiert die SMB CAs aus dem TSL Dokument und legt sie in einem PKCS12 Truststore ab.
    - legt eine Ergebnisdatei `smcb-trust-roots.p12` an
- TSL OCSP: Extrahiert die OCSP Signer aus dem TSL Dokument und legt sie in einem PKCS12 Truststore ab.
    - legt eine Ergebnisdatei `ocsp-signers.p12` an
- TPM: Konvertiert die kanonische .cab Datei in einen PKCS12 Truststore.
    - legt eine Ergebnisdatei `tpm-trust-roots.p12` an
- Policy Signer: Extrahiert die von der Policy Engine zu verwendenden Bundlesignaturschlüssel
- Roots.json: Erzeugt die `roots.json`

### Umgebungsvariablen

| Kategorie | Variable                                   | default                                                                                             | Beschreibung                                                                                                                                                                                                                                     | Pflichtfeld |
|-----------|--------------------------------------------|-----------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| Allgemein | `RESULT_DIR`                               |                                                                                                     | Ort an den die Verarbeiteten Ergebnisse gelegt werden sollen                                                                                                                                                                                     | Ja          |
| Allgemein | `TRUST_CERTCHAIN_FILE`                     |                                                                                                     | Dateiname der PEM Datei mit der Zertifikatskette für die Signatur des Provisioning Containers. Diese Datei muss dem Container zur Verfügung gestellt werden.                                                                                     | Ja          |
| Allgemein | `PROVISIONING_CONTAINER_NAME`              | `europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-provisioning/zeta-guard-provisioning:latest` | Name des Provisioning Containers.                                                                                                                                                                                                                | Nein        |
| Allgemein | `PROVISIONING_CONTAINER_REGISTRY_CA_FILE`  |                                                                                                     | Pfad zu einer PEM-Datei mit dem CA-Zertifikat, das das TLS-Zertifikat der Registry ausgestellt hat. Empfohlene Variante, da große Zertifikatsketten als Datei übergeben werden ohne das Kernel-Limit `ARG_MAX` zu überschreiten.                 | Nein        |
| Allgemein | `PROVISIONING_CONTAINER_REGISTRY_USERNAME` |                                                                                                     | Benutzername für die Authentifizierung an der OCI Registry. Nur nötig, wenn die Registry keinen anonymen Zugriff erlaubt. Muss zusammen mit `PROVISIONING_CONTAINER_REGISTRY_TOKEN` gesetzt werden.                                              | Nein        |
| Allgemein | `PROVISIONING_CONTAINER_REGISTRY_TOKEN`    |                                                                                                     | Passwort bzw. Token für die Authentifizierung an der OCI Registry. Muss zusammen mit `PROVISIONING_CONTAINER_REGISTRY_USERNAME` gesetzt werden.                                                                                                  | Nein        |
| Allgemein | `PROVISIONING_FILES_ROOT`                  | Der Container erstellt ein Verzeichnis via `mktemp -d`                                              | Ort an dem der Inhalt des Provisioning Container liegt                                                                                                                                                                                           | Nein        |
| Allgemein | `TRUSTSTORE_PASS`                          | `no_secret_for_trust_only`                                                                          | Passwort für Truststores                                                                                                                                                                                                                         | Nein        |
| Allgemein | `SCHEDULE_TIME`                            | nicht gesetzt (einmaliger Lauf)                                                                     | Format `HH:MM`, ausgewertet in der Zeitzone aus `TZ` (siehe unten). Wenn gesetzt, bleibt der Container resident und wiederholt den Verarbeitungslauf täglich zur angegebenen Uhrzeit. Ungültiges Format führt sofort zu einem Fehler beim Start. | Nein        |
| Allgemein | `TZ`                                       | nicht gesetzt (UTC)                                                                                 | IANA-Zeitzonenname (z. B. `Europe/Berlin`), in dem `SCHEDULE_TIME` ausgewertet wird. Das Image enthält `tzdata`, daher funktionieren beliebige benannte Zeitzonen. Ohne `SCHEDULE_TIME` hat diese Variable keine Wirkung.                        | Nein        |
| TSL SMB   | `PROCESSORS_TSL_SMB_ENABLED`               |                                                                                                     | Falls die SMB CAs aus der TSL aufbereitet werden sollen, muss diese Variable `true` sein.                                                                                                                                                        | Nein        |
| TSL SMB   | `TSL_FILENAME`                             | `ECC-RSA_TSL.xml`                                                                                   | Name der TSL Datei im Provisioning Container.                                                                                                                                                                                                    | Nein        |
| TSL SMB   | `SMB_RESULT_FILENAME`                      | `smcb-trust-roots.p12`                                                                              | Name der Datei mit dem Verarbeitungsergebnis des TSL SMB processor (PKCS12 Datei)                                                                                                                                                                | Nein        |
| TSL OCSP  | `PROCESSORS_TSL_OCSP_ENABLED`              |                                                                                                     | Falls die OCSP Signer aus der TSL aufbereitet werden sollen, muss diese Variable `true` sein.                                                                                                                                                    | Nein        |
| TSL OCSP  | `TSL_FILENAME`                             | `ECC-RSA_TSL.xml`                                                                                   | Name der TSL Datei im Provisioning Container.                                                                                                                                                                                                    | Nein        |
| TSL OCSP  | `OCSP_RESULT_FILENAME`                     | `ocsp-signers.p12`                                                                                  | Name der Datei mit dem Verarbeitungsergebnis des TSL OCSP processor (PKCS12 Datei)                                                                                                                                                               | Nein        |
| TPM       | `PROCESSORS_TPM_ENABLED`                   |                                                                                                     | Falls die TPM CAs aus der TSL aufbereitet werden sollen, muss diese Variable `true` sein.                                                                                                                                                        | Nein        |
| TPM       | `TPM_CAB_FILENAME`                         | `TrustedTpm.cab`                                                                                    | Name der .cab-Datei mit den TPM Zertifikaten im Provisioning Container.                                                                                                                                                                          | Nein        |
| TPM       | `TPM_RESULT_FILENAME`                      | `tpm-trust-roots.p12`                                                                               | Name der Datei mit dem Verarbeitungsergebnis des TPM processor (PKCS12 Datei)                                                                                                                                                                    | Nein        |
| Policy    | `PROCESSORS_POLICY_SIGNER_ENABLED`         |                                                                                                     | Falls das Policy Signer Zertifikat aufbereitet werden soll, muss diese Variable `true` sein.                                                                                                                                                     | Nein        |
| Policy    | `POLICY_SIGNER_CERT_FILENAME`              | `find "$PROVISIONING_FILES_ROOT/policy-engine-bundle-keys/signers" -not -type d \| head -n 1)`      | Name des end entity Zertifikatsdatei des Policy Signer Zertifikats.                                                                                                                                                                              | Nein        |
| Policy    | `POLICY_RESULT_FILENAME`                   | `policy-signer.pub`                                                                                 | Name der Datei mit dem Verarbeitungsergebnis des Policy processor (PEM encoded public key)                                                                                                                                                       | Nein        |
| Policy    | `PROCESSORS_ROOTS_JSON_ENABLED`            |                                                                                                     | Falls das `roots.json` bereitgestellt werden soll, muss diese Variable `true` sein.                                                                                                                                                              | Nein        |

## Kompilieren

Es muss lediglich der OCI container via docker gebaut werden:

```bash
docker buildx build -t provisioning-processor .
```

## Tests

Die Tests prüfen die einzelnen Prozessoren mit Testdaten aus `test/`.

### Im Docker-Image (empfohlen)

```bash
docker build -t provisioning-processor:test .
docker run --rm \
  -v "$(pwd)/test:/input:ro" \
  --entrypoint /bin/bash \
  provisioning-processor:test /input/run-tests.sh
```

Einen einzelnen Prozessor testen:

```bash
docker run --rm \
  -v "$(pwd)/test:/input:ro" \
  --entrypoint /bin/bash \
  provisioning-processor:test /input/tests/tsl-smb.sh
```

### Coverage (Docker)

```bash
docker buildx build -t provisioning-processor-coverage:test -f Dockerfile.test --load .
docker create --name coverage-run provisioning-processor-coverage:test
docker start -a coverage-run
docker cp coverage-run:/opt/provisioning-tools/coverage/. coverage/
docker rm coverage-run
```

Die Coverage-Ergebnisse liegen anschließend unter `coverage/` (HTML-Report und Sonar Generic Coverage).

### Lokal (erfordert openssl, xsltproc, cabextract, jq)

```bash
PROCESSORS_PATH="$(pwd)/src/processors" bash test/run-tests.sh
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
