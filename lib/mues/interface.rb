#!/usr/bin/ruby
###########################################################################
=begin

=Interface.rb

== Name

Interface - An interface metaclass

== Synopsis

  

== Description



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "metaclass/Operation"
require "metaclass/Attribute"
require "metaclass/Association"


module MetaClass

	class Interface < Object

		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: interface.rb,v 1.1 2001/03/15 02:24:22 deveiant Exp $


	end

end

