#!/usr/bin/ruby
###########################################################################
=begin

=SnoopFilter.rb

== Name

SnoopFilter - an IO snooping filter class

== Synopsis

  require "mues/filters/SnoopFilter"

== Description

This is a snooping filter class for IOEventStreams.

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
	class SnoopFilter < IOEventFilter

		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: snoopfilter.rb,v 1.1 2001/03/29 02:34:27 deveiant Exp $

		@@DefaultSortPosition = 300
	end # class SnoopFilter
end # module MUES


