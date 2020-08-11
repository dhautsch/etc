<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:gml="http://www.opengis.net/gml"
xmlns:georss="http://www.georss.org/georss"
xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata"
xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices"
xmlns:xxx="http://www.w3.org/2005/Atom"
xml:base="https://yoyodyne.sharepoint.com/sites/etl/_api/"
>
<!--

Note above the
        xmlns:xxx="http://www.w3.org/2005/Atom"
this is the default ns for MS SharePoint GetListReponse.
To make XSL work we have to add the :xxx and then
add the xxx: in front of: feed, entry, content below

Use this file with XmlTransform.java

Replace d:Title and d:PRODUCT_NAME with the columns you are interested in extracting.
Replace <xsl:text>&amp;</xsl:text> with the delimiter that you want.

 -->

<xsl:output method="text" encoding="iso-8859-1"/>

<xsl:param name="break" select="'&#xA;'" />

<xsl:template match="/">

        <th>HOST</th>
        <xsl:text>&amp;</xsl:text>
        <th>PRODUCT</th>
        <xsl:value-of select="$break" />

        <xsl:for-each select="xxx:feed/xxx:entry/xxx:content/m:properties">
                <td><xsl:value-of select="d:Title"/></td>
                <xsl:text>&amp;</xsl:text>
                <td><xsl:value-of select="d:PRODUCT_NAME"/></td>
                <xsl:value-of select="$break" />
        </xsl:for-each>

</xsl:template>

</xsl:stylesheet>
