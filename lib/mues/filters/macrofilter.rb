#!/usr/bin/ruby
###########################################################################
=begin

=MacroFilter.rb

== Name

MacroFilter - a user-defined macro filter class

== Synopsis

  require "mues/filters/MacroFilter"

== Description

This is a class for implementing user-definable macros (magic dictionary) in the
command shell.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/filters/IOEventFilter"

module MUES
	class MacroFilter < IOEventFilter

		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: macrofilter.rb,v 1.1 2001/03/29 02:34:27 deveiant Exp $

		@@DefaultSortPosition = 200

	end # class MacroFilter
end # module MUES

