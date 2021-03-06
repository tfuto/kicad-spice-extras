<?xml version="1.0" encoding="ISO-8859-1"?>

<!DOCTYPE xsl:stylesheet [
  <!ENTITY nl "&#xd;&#xa;">
]>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" omit-xml-declaration="yes" indent="no"/>

<xsl:variable name="spice_controller" select="export/components/comp/fields/field[@name='SPICE_CONTROLLER']" />
<xsl:variable name="spice_includes" select="export/components/comp/fields/field[@name='SPICE_FILE']" />
<xsl:variable name="spice_probe" select="export/nets/net/node[starts-with(@ref, 'VP')]" />

<xsl:template match="/export">
	<!-- file header -->
	<xsl:text>* </xsl:text>
	<xsl:value-of select="design/source" />
    <xsl:text>&nl;</xsl:text>
    <xsl:text>* Kicad to TINA netlist XSLT transformer &nl;&nl;</xsl:text>

	<!-- Includes -->
	<xsl:apply-templates mode="includes" select="$spice_includes" />
	<xsl:if test="$spice_includes">
		<xsl:text>&nl;</xsl:text>
	</xsl:if>

    <!-- Components -->
    <xsl:apply-templates mode="components" select="components/comp" />

	<!-- Connect ground node -->
	<xsl:apply-templates mode="ground" select="nets/net[@name='GND']" />

	<!-- Process controllers -->
	<xsl:apply-templates mode="controller" select="$spice_controller"/>

	<!-- Process voltage probes -->
	<xsl:if test="$spice_probe">
		<xsl:call-template name="vprobe" />
	</xsl:if>

    <!-- Footer -->
    <xsl:text>&nl;.END&nl;</xsl:text>
</xsl:template>

<xsl:template name="vprobe">
	<xsl:text>.PRINT </xsl:text>
	<xsl:apply-templates mode="controller_name" select="$spice_controller"/>
	<xsl:apply-templates mode="vprobe_apply" select="$spice_probe" />
	<xsl:text>&nl;</xsl:text>
</xsl:template>

<xsl:template match="net/node" mode="vprobe_apply">
	<xsl:text> V(</xsl:text>
	<xsl:call-template name="net_name">
		<xsl:with-param name="net_code" select="../@code" />
		<xsl:with-param name="net_name" select="../@name" />
	</xsl:call-template>
	<xsl:text>)</xsl:text>
</xsl:template>

<xsl:template match="components/comp/fields/field" mode="controller">
	<xsl:text>.</xsl:text>
	<xsl:value-of select="." />
	<xsl:text> </xsl:text>
	<xsl:value-of select="../field[@name='SPICE_PARAMS']" />
	<xsl:text>&nl;</xsl:text>
</xsl:template>

<xsl:template match="components/comp/fields/field" mode="includes">
	<xsl:text>.INCLUDE </xsl:text>
	<xsl:value-of select="." />
	<xsl:text>&nl;</xsl:text>
</xsl:template>

<xsl:template match="components/comp/fields/field" mode="controller_name">
	<xsl:value-of select="." />
</xsl:template>

<xsl:template name="node_tokenize">
	<xsl:param name="text" select="."/>
	<xsl:param name="separator" select="','"/>
	<xsl:param name="component" />
	<xsl:variable name="call_next" select="not(contains($text, $separator))" />

	<xsl:text> </xsl:text>

	<xsl:choose>
		<xsl:when test="$call_next">
			<item>
				<xsl:variable name="index" select="normalize-space($text)" />
				<xsl:variable name="net" select="../../nets/net/node[@ref=$component][@pin=$index]/.." />
			
				<xsl:call-template name="net_name">
					<xsl:with-param name="net_code" select="$net/@code" />
					<xsl:with-param name="net_name" select="$net/@name" />
				</xsl:call-template>		
			</item>
		</xsl:when>
		<xsl:otherwise>
			<xsl:variable name="index" select="normalize-space(substring-before($text, $separator))" />
			<xsl:variable name="net" select="../../nets/net/node[@ref=$component][@pin=$index]/.." />

			<xsl:call-template name="net_name">
				<xsl:with-param name="net_code" select="$net/@code" />
				<xsl:with-param name="net_name" select="$net/@name" />
			</xsl:call-template>

			<xsl:call-template name="node_tokenize">
				<xsl:with-param name="text" select="substring-after($text, $separator)"/>
				<xsl:with-param name="component" select="$component" />
			</xsl:call-template>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- for each component -->
<xsl:template match="components/comp" mode="components">
    <xsl:variable name="ref" select="@ref" />

    <!-- Do not process spice-extras components -->
    <xsl:choose>
    	<xsl:when test="fields/field[@name='SPICE_EXTRA']"></xsl:when>
    	<xsl:otherwise>
    		<xsl:if test="starts-with(@ref, 'U')">
    			<xsl:text>X</xsl:text>
    		</xsl:if>
			<xsl:value-of select="@ref"/>

		    <!-- Apply transformation to a list of nodes associated with this component-->
		    <xsl:choose>
		    	<xsl:when test="fields/field[@name='Spice_Node_Sequence']">
					<xsl:call-template name="node_tokenize">
						<xsl:with-param name="component" select="@ref" />
						<xsl:with-param name="text" select="fields/field[@name='Spice_Node_Sequence']" />
					</xsl:call-template>
		    	</xsl:when>
		    	<xsl:otherwise>
					<xsl:apply-templates select="../../nets/net/node[@ref=$ref]">
			    		<xsl:sort select="@pin" />
			    		<xsl:with-param name="component">
			    			<xsl:value-of select="@ref"/>
			    		</xsl:with-param>
			 		</xsl:apply-templates>
		    	</xsl:otherwise>
		    </xsl:choose>
		    
			<xsl:text> </xsl:text>
			<xsl:value-of select="value" />

		    <xsl:text>&nl;</xsl:text>
	    </xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template mode="ground" match="nets/net">
	<xsl:text>R_GND </xsl:text>
	<xsl:value-of select="@code" />
	<xsl:text>_</xsl:text>
	<xsl:value-of select="@name" />
	<xsl:text> 0 0&nl;&nl;</xsl:text>
</xsl:template>

<xsl:template match="net/node">
	<xsl:param name="component" />
	<xsl:text> </xsl:text>

	<xsl:call-template name="net_name">
		<xsl:with-param name="net_code" select="../@code" />
		<xsl:with-param name="net_name" select="../@name" />
	</xsl:call-template>
</xsl:template>

<xsl:template name="net_name">
	<xsl:param name="net_code" />
	<xsl:param name="net_name" />

	<!--  Check for default name -->
	<xsl:choose>
		<xsl:when test="starts-with($net_name, 'Net-(')">
			<xsl:value-of select="$net_code" />
		</xsl:when>
		<xsl:otherwise>
			<!-- For TINA, net name should start with a number -->
			<xsl:value-of select="$net_code" />
			<xsl:text>_</xsl:text>
			<xsl:value-of select="translate($net_name, '-/()+', '')" />
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

</xsl:stylesheet>
