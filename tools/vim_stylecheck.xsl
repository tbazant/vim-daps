<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  exclude-result-prefixes="">
  <xsl:output mode="text"/>

  <xsl:template match="node()|@*"/>
  <xsl:template match="node()|@*" mode="message"/>

  <xsl:param name="delimiter">::</xsl:param>

  <xsl:template match="/">
    <xsl:for-each select="//result">
      <xsl:sort select="location/file"/>
      <xsl:sort select="location/line" data-type="number"/>
      <xsl:apply-templates select="."/>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="result">
    <xsl:value-of select="location/file"/>
    <xsl:value-of select="$delimiter"/>
    <xsl:value-of select="location/line"/>
    <xsl:value-of select="$delimiter"/>
    <xsl:value-of select="@type"/>
    <xsl:value-of select="$delimiter"/>
    <xsl:value-of select="../part-title"/>
    <xsl:value-of select="$delimiter"/>
    <xsl:apply-templates select="message" mode="message"/>
    <xsl:text> SUGGESTIONS </xsl:text>
    <xsl:apply-templates select="suggestion" mode="message"/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="message" mode="message">
    <xsl:apply-templates mode="message"/>
  </xsl:template>

  <xsl:template match="suggestion" mode="message">
    <xsl:text> * </xsl:text>
    <xsl:apply-templates select="node()" mode="message"/>
  </xsl:template>

  <xsl:template match="quote" mode="message">
    <xsl:text> "</xsl:text>
    <xsl:apply-templates select="node()" mode="message"/>
    <xsl:text>" </xsl:text>
  </xsl:template>

  <xsl:template match="highlight" mode="message">
    <xsl:text> |[</xsl:text>
    <xsl:apply-templates select="node()" mode="message"/>
    <xsl:text>]| </xsl:text>
  </xsl:template>

  <xsl:template match="tag" mode="message">
    <xsl:text disable-output-escaping="yes"> &lt;</xsl:text>
    <xsl:apply-templates select="node()" mode="message"/>
    <xsl:text disable-output-escaping="yes">&gt; </xsl:text>
  </xsl:template>

  <xsl:template match="id" mode="message">
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="node()" mode="message"/>
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="text()" mode="message">
    <xsl:value-of select="normalize-space(translate(.,'&#10;',' '))"/>
  </xsl:template>

</xsl:stylesheet>
