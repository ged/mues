#!/usr/bin/ruby
#################################################################
=begin

=EnvironmentEvents.rb

== Name

EnvironmentEvents - A collection of environment event classes

== Synopsis

  LoadEnvironmentEvent.new( environmentNameString )
  UnloadEnvironmentEvent.new( environmentNameString )  

== Description

This module contains event classes the instances of which are used to interact
with Environment objects in the MUES.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "mues/Namespace"
require "mues/Exceptions"

require "mues/events/BaseClass"

module MUES

	#################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	#################################################################

	### (ABSTRACT) CLASS: EnvironmentEvent < Event
	class EnvironmentEvent < Event ; implements AbstractClass, Debuggable

		attr_reader :user

		def initialize( user=nil )
			checkType( user, NilClass, MUES::User )
			@user = user
			super()
		end
	end


	#################################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	#################################################################

	### CLASS: LoadEnvironmentEvent < EnvironmentEvent
	class LoadEnvironmentEvent < EnvironmentEvent

		attr_reader :name, :spec
		
		### METHOD: initialize( name, spec[, user=MUES::User] )
		### Intitialize the event to load an instance of the environment spec
		### specified and associate it with the given name. If the optional user
		### argument is given, the status of the event will be sent to them as
		### an OutputEvent.
		def initialize( name, spec, user=nil )
			checkEachType( [name,spec], String )
			checkType( user, NilClass, MUES::User )

			@name = name
			@spec = spec

			super( user )
		end

	end

	### CLASS: UnloadEnvironmentEvent < EnvironmentEvent
	class UnloadEnvironmentEvent < EnvironmentEvent
		attr_reader :name

		### METHOD: initialize( envOrEnvname[, user=MUES::User] )
		### Initialize the object with the environment specified as its
		### target. The target may be either an environment object or the name
		### associated with it in the Engine.
		def initialize( name, user=nil )
			checkType( name, ::String )

			@name = name
			super( user )
		end
	end

end # module MUES

