#!/usr/bin/ruby
###########################################################################
=begin

=WorldEvents.rb

== Name

WorldEvents - A collection of world event classes

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

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Debugging"

require "mues/events/BaseClass"

module MUES

	###########################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	###########################################################################

	### (ABSTRACT) CLASS: WorldEvent < Event
	class WorldEvent < Event ; implements AbstractClass
	end


end # module MUES

