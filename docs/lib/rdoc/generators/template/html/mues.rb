#
# = FaerieMUD MUES RDoc HTML template
#
# This is an HTML template for RDoc that dictates a bit more of the appearance
# of the output to cascading stylesheets than the default. It is designed for
# inline code, and will toggle the display of each method's source with a click
# on the method name.
#
# == CVSID
#
#   $Id: mues.rb,v 1.3 2002/05/28 17:07:24 deveiant Exp $
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
#
# Copyright (c) 2002 The FaerieMUD Consortium. All rights reserved.
#
# This document is Open Content. You may use, modify, and/or redistribute this
# document under the terms of the Open Content License. (See
# http://www.opencontent.org/ for details)
#

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

XHTML_PREAMBLE = %{<?xml version="1.0" encoding="%charset%"?>
<!DOCTYPE html 
     PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
     "DTD/xhtml1-transitional.dtd">
}

HEADER = XHTML_PREAMBLE + %{
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
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<title>%title%</title>
	<meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
	<meta http-equiv="Content-Script-Type" content="text/javascript" />
	<link rel="stylesheet" href="http://www.FaerieMUD.org/stylesheets/rdoc.css" type="text/css" media="screen" />
	<script type="text/javascript">
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
	</script>

</head>
<body>
}


#####################################################################
###	C O N T E X T   C O N T E N T   T E M P L A T E
#####################################################################

CONTEXT_CONTENT = %{
	<div id="contextContent">
IF:diagram
		<div id="diagram">
			%diagram%
		</div>
ENDIF:diagram

IF:description
		<div id="description">
			%description%
		</div>
ENDIF:description

IF:requires
		<div id="requires-list">
			<h2 class="section-bar">Required files</h2>

			<div class="name-list">
START:requires
			HREF:aref:name:&nbsp;&nbsp;
END:requires
			</div>
		</div>
ENDIF:requires

IF:methods
		<div id="method-index">
			<h2 class="section-bar">Methods</h2>

			<div id="method-index-list">
START:methods
			HREF:aref:name:&nbsp;&nbsp;
END:methods
			</div>
		</div>
ENDIF:methods

IF:attributes
		<div id="attributes">
			<h2 class="section-bar">Attributes</h2>

			<div id="attribute-list">
				<table>

START:attributes
				<tr valign="top">
					<td class="attr-name">%name%</td>
					<td align="center" class="attr-rw">&nbsp;[%rw%]&nbsp;</td>
					<td>%a_desc%</td>
				</tr>

END:attributes
				</table>
			</div>
		</div>
ENDIF:attributes
			
IF:classlist
		<div id="class-list">
			<h2 class="section-bar">Classes and Modules</h2>

			%classlist%
		</div>
ENDIF:classlist

	</div>

}


#####################################################################
###	F O O T E R   T E M P L A T E
#####################################################################
FOOTER = %{
<div id="validator-badges">
  <p><a href="http://validator.w3.org/check/referer"><img
        src="/images/valid-xhtml10.png"
        alt="Valid XHTML 1.0!" height="31" width="88" border="0" /></a>
  </p>
</div>

<div id="copyright">
	<p>Copyright &copy; 1999-2002, <a href="http://www.FaerieMUD.org/">The FaerieMUD
	Consortium</a>. This material may be distributed only subject to the terms and
	conditions set forth in the Open Publication License, v1.0 or later (the latest
	version is presently available at &lt;<a
	href="http://www.opencontent.org/openpub/">http://www.opencontent.org/openpub/</a>&gt;). Distribution
	of substantively modified versions of this document is prohibited without the
	explicit permission of the copyright holder.</p>
</div>

</body>
</html>
}


#####################################################################
###	F I L E   P A G E   H E A D E R   T E M P L A T E
#####################################################################

FILE_PAGE = %{
	<div id="fileHeader">
		<h1>%short_name%</h1>
		<table class="header-table">
		<tr valign="top"><td><strong>Path:</strong></td><td>%full_path%</td></tr>
		<tr valign="top"><td><strong>Last Update:</strong></td><td>%dtm_modified%</td></tr>
		</table>
	</div>
}


#####################################################################
###	C L A S S   P A G E   H E A D E R   T E M P L A T E
#####################################################################

CLASS_PAGE = %{
    <div id="classHeader">
        <h1>%full_name% <sup class="typeNote">(%classmod%)</sup></h1>
        <table class="header-table">
        <tr valign="top">
            <td><strong>In:</strong></td>
            <td>
START:infiles
IF:full_path_url
                <a href="%full_path_url%">
ENDIF:full_path_url
                %full_path%
IF:full_path_url
                </a>
ENDIF:full_path_url
<br />
END:infiles
            </td>
        </tr>
        </table>

IF:parent
        <table class="header-table">
        <tr valign="top">
            <td><strong>Parent:</strong>
            <td>
IF:par_url
                <a href="%par_url%">
ENDIF:par_url
                %parent%
IF:par_url
               </a>
ENDIF:par_url
            </td>
        </tr>
        </table>
ENDIF:parent
    </div>
}


#####################################################################
###	M E T H O D   L I S T   T E M P L A T E
#####################################################################

METHOD_LIST = %{

		<!-- if includes -->
IF:includes
		<div id="includes">
			<h2 class="section-bar">Included Modules</h2>

			<div id="includes-list">
START:includes
		    <span class="include-name">HREF:aref:name:</span>
END:includes
			</div>
		</div>
ENDIF:includes


		<!-- if method_list -->
IF:method_list
		<div id="methods">
START:method_list
IF:methods
			<h2 class="section-bar">%type% %category% methods</h2>

START:methods
			<!-- %name%%params% -->
			<div id="method-%aref%" class="method-detail">
				<a name="%aref%"></a>

				<div class="method-heading">
IF:codeurl
					<a href="%codeurl%" target="Code" class="method-signature"
						onclick="popupCode('%codeurl%');return false;">
ENDIF:codeurl
IF:sourcecode
					<a href="#%aref%" class="method-signature"
						onclick="toggleCode('%aref%-source');return false;">
ENDIF:sourcecode
					<span class="method-name">%name%</span><span class="method-args">%params%</span>
IF:codeurl
					</a>
ENDIF:codeurl
IF:sourcecode
					</a>
ENDIF:sourcecode
				</div>
			
				<div class="method-description">
IF:m_desc
					%m_desc%
ENDIF:m_desc
IF:sourcecode
					<div class="method-source-code" id="%aref%-source">
<pre>
%sourcecode%
</pre>
					</div>
ENDIF:sourcecode
				</div>
			</div>

END:methods
ENDIF:methods
END:method_list

		</div>
ENDIF:method_list
}


#####################################################################
###	B O D Y   T E M P L A T E
#####################################################################

BODY = HEADER + %{

!INCLUDE!  <!-- banner header -->

	<div id="bodyContent">

} + CONTEXT_CONTENT + METHOD_LIST + %{

	</div>

} + FOOTER



#####################################################################
###	S O U R C E   C O D E   T E M P L A T E
#####################################################################

SRC_PAGE = XHTML_PREAMBLE + %{
<!--

    The FaerieMUD Consortium: %title%

    Author:     Michael Granger
    Copyright (c) 1999-2002 The FaerieMUD Consortium. All rights reserved.

    This document is Open Content. You may use, modify, and/or redistribute this
    document under the terms of the Open Content License. (See
    http://www.opencontent.org/ for details)

	  They arise spontaneously,
        the principles of all things.

      Water need not think
        to offer itself as a home
          for clean moonlight.

        - Sogi

  -->
<html>
<head>
	<title>%title%</title>
	<meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
	<link rel="stylesheet" href="http://www.FaerieMUD.org/stylesheets/rdoc.css" type="text/css" />
</head>
<body>
	<pre>%code%</pre>
</body>
</html>
}


#####################################################################
###	I N D E X   F I L E   T E M P L A T E S
#####################################################################

FR_INDEX_BODY = %{
!INCLUDE!
}

FILE_INDEX = XHTML_PREAMBLE + %{
<!--

    The FaerieMUD Consortium: %list_title%

    Author:     Michael Granger
    Copyright (c) 1999-2002 The FaerieMUD Consortium. All rights reserved.

    This document is Open Content. You may use, modify, and/or redistribute this
    document under the terms of the Open Content License. (See
    http://www.opencontent.org/ for details)

  -->
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<title>%list_title%</title>
	<meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
	<link rel="stylesheet" href="rdoc-style.css" type="text/css" />
	<base target="docwin" />
</head>
<body>
<div id="index">
	<h1 class="section-bar">%list_title%</h1>
	<div id="index-entries">
START:entries
		<a href="%href%">%name%</a><br />
END:entries
	</div>
</div>
</body>
</html>
}

CLASS_INDEX = FILE_INDEX
METHOD_INDEX = FILE_INDEX

INDEX = %{<?xml version="1.0" encoding="%charset%"?>
<!DOCTYPE html 
     PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN"
     "DTD/xhtml1-frameset.dtd">

<!--

    The FaerieMUD Consortium: %title%

    Author:     Michael Granger
    Copyright (c) 1999-2002 The FaerieMUD Consortium. All rights reserved.

    This document is Open Content. You may use, modify, and/or redistribute this
    document under the terms of the Open Content License. (See
    http://www.opencontent.org/ for details)

  -->
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<title>%title%</title>
	<meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
</head>
<frameset rows="20%, 80%">
    <frameset cols="25%,35%,45%">
        <frame src="fr_file_index.html"   title="Files" name="Files" />
        <frame src="fr_class_index.html"  name="Classes" />
        <frame src="fr_method_index.html" name="Methods" />
    </frameset>
    <frame src="%initial_page%" name="docwin" />
</frameset>
</html>
}


	end # module Page
end # class RDoc

