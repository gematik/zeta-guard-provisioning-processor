<?xml version="1.0"?>
<!--
  ~ /*-
  ~  * #%L
  ~  * provisioning-processor
  ~  * %%
  ~  * (C) tech@Spree GmbH, 2026, licensed for gematik GmbH
  ~  * %%
  ~  * Licensed under the Apache License, Version 2.0 (the "License");
  ~  * you may not use this file except in compliance with the License.
  ~  * You may obtain a copy of the License at
  ~  *
  ~  *     http://www.apache.org/licenses/LICENSE-2.0
  ~  *
  ~  * Unless required by applicable law or agreed to in writing, software
  ~  * distributed under the License is distributed on an "AS IS" BASIS,
  ~  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  ~  * See the License for the specific language governing permissions and
  ~  * limitations under the License.
  ~  *
  ~  * *******
  ~  *
  ~  * For additional notes and disclaimer from gematik and in case of changes by gematik find details in the "Readme" file.
  ~  * #L%
  ~  */
  -->
<xsl:stylesheet
        version="1.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:tsl="http://uri.etsi.org/02231/v2#">

    <xsl:output method="text" encoding="UTF-8"/>

    <xsl:template match="/">
        <xsl:for-each select="tsl:TrustServiceStatusList
                              /tsl:TrustServiceProviderList
                              /tsl:TrustServiceProvider
                              /tsl:TSPServices
                              /tsl:TSPService[
                                  tsl:ServiceInformation/tsl:ServiceStatus = 'http://uri.etsi.org/TrstSvc/Svcstatus/inaccord'
                                  and
                                  tsl:ServiceInformation
                                  /tsl:ServiceInformationExtensions
                                  /tsl:Extension[
                                      tsl:ExtensionOID = '1.2.276.0.76.4.77'
                                      and
                                      tsl:ExtensionValue = 'oid_smc_b_aut'
                                  ]
                              ]">
            <xsl:text>friendlyName=</xsl:text>
            <xsl:value-of select="tsl:ServiceInformation
                              /tsl:ServiceName
                              /tsl:Name"/>
            <xsl:text>&#10;</xsl:text>
            <xsl:text>-----BEGIN CERTIFICATE-----&#10;</xsl:text>
            <xsl:value-of select="tsl:ServiceInformation
                              /tsl:ServiceDigitalIdentity
                              /tsl:DigitalId
                              /tsl:X509Certificate"/>
            <xsl:text>&#10;-----END CERTIFICATE-----&#10;</xsl:text>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>