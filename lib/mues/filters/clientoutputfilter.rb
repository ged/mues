#!/usr/bin/ruby
###########################################################################
=begin

=ClientOutputFilter.rb

== Name

ClientOutputFilter - a player client output filter class

== Synopsis

  require "mues/filters/ClientOutputFilter"

== Description

This is a filter used to process the I/O stream appropriately for a player game client.

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

		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: clientoutputfilter.rb,v 1.2 2001/05/14 12:32:55 deveiant Exp $
		DefaultSortPosition = 101

	end # class ClientOutputFilter
end # module MUES

