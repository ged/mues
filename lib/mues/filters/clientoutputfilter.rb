#!/usr/bin/ruby
###########################################################################
=begin

=ClientOutputFilter.rb

== Name

ClientOutputFilter - a user client output filter class

== Synopsis

  require "mues/filters/ClientOutputFilter"

== Description

This is a filter used to process the I/O stream appropriately for a user game client.

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
	class ClientOutputFilter < IOEventFilter

		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: clientoutputfilter.rb,v 1.3 2001/07/27 04:08:27 deveiant Exp $
		DefaultSortPosition = 101

	end # class ClientOutputFilter
end # module MUES

