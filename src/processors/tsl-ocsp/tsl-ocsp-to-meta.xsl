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

    <!-- Strip ", ', and \ from a string before embedding it in JSON -->
    <xsl:template name="sanitize-name">
        <xsl:param name="s"/>
        <xsl:value-of select="translate($s, concat('&quot;\', &quot;'&quot;), '')"/>
    </xsl:template>

    <xsl:template match="/">
        <xsl:text>[</xsl:text>
        <xsl:variable name="services" select="tsl:TrustServiceStatusList
                              /tsl:TrustServiceProviderList
                              /tsl:TrustServiceProvider
                              /tsl:TSPServices
                              /tsl:TSPService[
                                  tsl:ServiceInformation
                                  /tsl:ServiceTypeIdentifier = 'http://uri.etsi.org/TrstSvc/Svctype/Certstatus/OCSP'
                                  and
                                  tsl:ServiceInformation
                                  /tsl:ServiceStatus = 'http://uri.etsi.org/TrstSvc/Svcstatus/inaccord'
                              ]"/>
        <xsl:for-each select="$services">
            <xsl:text>&#10;  {</xsl:text>
            <xsl:text>&#10;    "friendlyName": "</xsl:text>
            <xsl:call-template name="sanitize-name">
                <xsl:with-param name="s" select="tsl:ServiceInformation/tsl:ServiceName/tsl:Name"/>
            </xsl:call-template>
            <xsl:text>",</xsl:text>
            <xsl:text>&#10;    "tspName": "</xsl:text>
            <xsl:call-template name="sanitize-name">
                <xsl:with-param name="s" select="../../tsl:TSPInformation/tsl:TSPTradeName/tsl:Name"/>
            </xsl:call-template>
            <xsl:text>"</xsl:text>
            <xsl:text>&#10;  }</xsl:text>
            <xsl:if test="position() != last()">
                <xsl:text>,</xsl:text>
            </xsl:if>
        </xsl:for-each>
        <xsl:text>&#10;]&#10;</xsl:text>
    </xsl:template>
</xsl:stylesheet>
