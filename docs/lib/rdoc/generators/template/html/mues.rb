module RDoc
	module Page

		FONTS = "Verdana,Arial,Helvetica,sans-serif"

STYLE = %{/*
 * Inherit the real stylesheet
 */
@import url("http://www.FaerieMUD.org/stylesheets/rdoc.css");

}


#####################################################################
###	H E A D E R   T E M P L A T E  
#####################################################################

HEADER = %{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<!--

    The FaerieMUD Consortium: %title%

    Author:     Michael Granger
        
    Copyright (c) 1999-2002 The FaerieMUD Consortium. All rights reserved.

    This document is Open Content. You may use, modify, and/or redistribute this
    document under the terms of the Open Content License. (See
    http://www.opencontent.org/ for details)

      "The way is empty yet use will not drain it."
      - Lao-Tzu

  -->
<HTML>
<HEAD>
	<TITLE>%title%</TITLE>
	<META http-equiv="Content-Type" content="text/html; charset=%charset%">
	<LINK rel="stylesheet" href="http://www.FaerieMUD.org/stylesheets/rdoc.css" type="text/css" media="screen">
	<SCRIPT language="javascript" type="text/javascript">
	<!-- Hide

	function popupCode( url ) {
		window.open(url, "Code", "resizable=yes,scrollbars=yes,toolbar=no,status=no,height=150,width=400")
	}

	function toggleCode( id ) {
		if ( document.getElementById )
			elem = document.getElementById( id );
		else if ( document.all )
			elem = eval( "document.all." + id );
		else
			return false;

		elemStyle = elem.style;
		
		if ( elemStyle.display != "block" ) {
			elemStyle.display = "block"
		} else {
			elemStyle.display = "none"
		}

		return true;
	}
	
	// Unhide --> 
	</SCRIPT>

</HEAD>
<BODY>
}


#####################################################################
###	C O N T E X T   C O N T E N T   T E M P L A T E
#####################################################################

CONTEXT_CONTENT = %{
	<DIV class="contextContent">
IF:diagram
		<DIV id="diagram">
			%diagram%
		</DIV>
ENDIF:diagram

IF:description
		<DIV id="description">
			%description%
		</DIV>
ENDIF:description

IF:requires
		<DIV id="requires-list">
			<H2 class="section-bar">Required files</H2>

			<div class="name-list">
START:requires
			HREF:aref:name:&nbsp;&nbsp;
END:requires
			</div>
		</DIV>
ENDIF:requires

IF:methods
		<DIV id="method-index">
			<H2 class="section-bar">Methods</H2>

			<DIV id="method-index-list">
START:methods
			HREF:aref:name:&nbsp;&nbsp;
END:methods
			</DIV>
		</DIV>
ENDIF:methods

IF:attributes
		<DIV id="attributes">
			<H2 class="section-bar">Attributes</H2>

			<DIV id="attribute-list">
				<TABLE>

START:attributes
				<TR valign="top">
					<TD class="attr-name">%name%</td>
					<TD align="center" class="attr-rw">&nbsp;[%rw%]&nbsp;</td>
					<TD>%a_desc%</TD>
				</TR>

END:attributes
				</TABLE>
			</DIV>
		</DIV>
ENDIF:attributes
			
IF:classlist
		<DIV id="class-list">
			<H2 class="section-bar">Classes and Modules</H2>

			%classlist%
		</DIV>
ENDIF:classlist

	</DIV>

}


#####################################################################
###	F O O T E R   T E M P L A T E
#####################################################################
FOOTER = %{
<DIV id="copyright">
	<P>Copyright &copy; 1999-2002, <A href="http://www.FaerieMUD.org/">The FaerieMUD
	Consortium</A>. This material may be distributed only subject to the terms and
	conditions set forth in the Open Publication License, v1.0 or later (the latest
	version is presently available at &lt;<A
	href="http://www.opencontent.org/openpub/">http://www.opencontent.org/openpub/</A>&gt;). Distribution
	of substantively modified versions of this document is prohibited without the
	explicit permission of the copyright holder.</P>
</DIV>

</BODY>
</HTML>
}


#####################################################################
###	F I L E   P A G E   H E A D E R   T E M P L A T E
#####################################################################

FILE_PAGE = %{
	<DIV id="fileHeader">
		<H1>%short_name%</H1>
		<TABLE class="header-table">
		<TR valign="top"><TD><STRONG>Path:</STRONG></TD><TD>%full_path%</TD></TR>
		<TR valign="top"><TD><STRONG>Last Update:</STRONG></TD><TD>%dtm_modified%</TD></TR>
		</TABLE>
	</DIV>
}


#####################################################################
###	C L A S S   P A G E   H E A D E R   T E M P L A T E
#####################################################################

CLASS_PAGE = %{
    <DIV id="classHeader">
        <H1>%full_name% <SUP class="typeNote">(%classmod%)</SUP></H1>
        <TABLE class="header-table">
        <TR valign="top">
            <TD><STRONG>In:</STRONG></TD>
            <TD>
START:infiles
IF:full_path_url
                <a href="%full_path_url%">
ENDIF:full_path_url
                %full_path%
IF:full_path_url
                </a>
ENDIF:full_path_url
<br>
END:infiles
            </TD>
        </TR>
        </TABLE>

IF:parent
        <TABLE class="header-table">
        <TR valign="top">
            <TD><STRONG>Parent:</STRONG>
            <TD>
IF:par_url
                <a href="%par_url%">
ENDIF:par_url
                %parent%
IF:par_url
               </a>
ENDIF:par_url
            </TD>
        </TR>
        </TABLE>
ENDIF:parent
    </DIV>
}


#####################################################################
###	M E T H O D   L I S T   T E M P L A T E
#####################################################################

METHOD_LIST = %{

		<!-- if includes -->
IF:includes
		<DIV id="includes">
			<H2 class="section-bar">Included Modules</H2>

			<DIV id="includes-list">
START:includes
		    <SPAN class="include-name">HREF:aref:name:</span>
END:includes
		</DIV>
ENDIF:includes


		<!-- if method_list -->
IF:method_list
		<DIV id="methods">
START:method_list
IF:methods
			<H2 class="section-bar">%type% %category% methods</H2>

START:methods
			<!-- %name%%params% -->
			<DIV id="method-%aref%" class="method-detail">
				<A name="%aref%"></a>

				<DIV class="method-signature">
IF:codeurl
					<A href="%codeurl%" target="Code" class="methodtitle"
						onClick="popupCode('%codeurl%');return false;">
ENDIF:codeurl
IF:sourcecode
					<A href="#" class="methodtitle"
						onClick="toggleCode('%aref%-source');return false;">
ENDIF:sourcecode
					<H3 class="method-name">%name%<SPAN class="method-args">%params%</SPAN></H3>
IF:codeurl
					</A>
ENDIF:codeurl
IF:sourcecode
					</A>
ENDIF:sourcecode
				</DIV>
			
				<DIV class="method-description">
IF:m_desc
					%m_desc%
ENDIF:m_desc
IF:sourcecode
					<DIV class="source-code" id="%aref%-source">
<PRE>
%sourcecode%
</PRE>
					</DIV>
ENDIF:sourcecode
				</DIV>
			</DIV>

END:methods
ENDIF:methods
END:method_list

		</DIV>
ENDIF:method_list
}


#####################################################################
###	B O D Y   T E M P L A T E
#####################################################################

BODY = HEADER + %{

!INCLUDE!  <!-- banner header -->

	<DIV id="bodyContent">

} + CONTEXT_CONTENT + METHOD_LIST + %{

	</DIV>

} + FOOTER



#####################################################################
###	S O U R C E   C O D E   T E M P L A T E
#####################################################################

SRC_PAGE = %{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<!--

    The FaerieMUD Consortium: %title%

    Author:     Michael Granger
        
    Copyright (c) 1999-2002 The FaerieMUD Consortium. All rights reserved.

    This document is Open Content. You may use, modify, and/or redistribute this
    document under the terms of the Open Content License. (See
    http://www.opencontent.org/ for details)

      "The way is empty yet use will not drain it."
      - Lao-Tzu

  -->
<HTML>
<HEAD>
	<META http-equiv="Content-Type" content="text/html; charset=%charset%">
	<TITLE>%title%</TITLE>
	<LINK rel="stylesheet" href="http://www.FaerieMUD.org/stylesheets/rdoc.css" type="text/css">
</HEAD>
<BODY>
	<PRE>%code%</PRE>
</BODY>
</HTML>
}


#####################################################################
###	I N D E X   F I L E   T E M P L A T E S
#####################################################################

FR_INDEX_BODY = %{
!INCLUDE!
}

FILE_INDEX = %{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<!--

    The FaerieMUD Consortium: %list_title%

    Author:     Michael Granger
        
    Copyright (c) 1999-2002 The FaerieMUD Consortium. All rights reserved.

    This document is Open Content. You may use, modify, and/or redistribute this
    document under the terms of the Open Content License. (See
    http://www.opencontent.org/ for details)

      "The way is empty yet use will not drain it."
      - Lao-Tzu

  -->
<HTML>
<HEAD>
	<TITLE>%list_title%</TITLE>
	<META http-equiv="Content-Type" content="text/html; charset=%charset%">
	<LINK rel="stylesheet" href="rdoc-style.css" type="text/css">
	<BASE target="docwin">
</HEAD>
<BODY>
<DIV id="index">
	<H1 class="section-bar">%list_title%</H1>
	<DIV id="index-entries">
START:entries
		<A href="%href%">%name%</a><br />
END:entries
	</DIV>
</DIV>
</BODY>
</HTML>
}

CLASS_INDEX = FILE_INDEX
METHOD_INDEX = FILE_INDEX

INDEX = %{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<!--

    The FaerieMUD Consortium: %title%

    Author:     Michael Granger
        
    Copyright (c) 1999-2002 The FaerieMUD Consortium. All rights reserved.

    This document is Open Content. You may use, modify, and/or redistribute this
    document under the terms of the Open Content License. (See
    http://www.opencontent.org/ for details)

      "The way is empty yet use will not drain it."
      - Lao-Tzu

  -->
<HTML>
<HEAD>
	<TITLE>%title%</title></HEAD>

	<META http-equiv="Content-Type" content="text/html; charset=%charset%">
</HEAD>
<frameset rows="20%, 80%">
    <frameset cols="25%,35%,45%">
        <frame src="fr_file_index.html"   title="Files" name="Files">
        <frame src="fr_class_index.html"  name="Classes">
        <frame src="fr_method_index.html" name="Methods">
    </frameset>
    <frame  src="%initial_page%" name="docwin">
</frameset>
<noframes>
	  <body bgcolor="white">
		Click <a href="html/index.html">here</a> for a non-frames
		version of this page.
	  </body>
</noframes>
</HTML>
}


end
end
