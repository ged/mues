#!/usr/bin/ruby
###########################################################################
=begin

=Interface.rb

== Name

Interface - An interface metaclass

== Synopsis

  

== Description



== Author

Michael Granger <ged@FaerieMUD.org>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require 'metaclass/Constants'

module Metaclass

	autoload :Operation, "metaclass/Operation"
	autoload :Attribute, "metaclass/Attribute"
	autoload :Association, "metaclass/Association"

	class Interface

		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: interface.rb,v 1.3 2002/03/30 19:15:24 deveiant Exp $


	end

end

