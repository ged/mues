#!/usr/bin/ruby
###########################################################################
=begin

=engine.rb

== Name

engine - Engine admin commands

== Description

This is a collection of administrative commands for controlling the MUES Engine.

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
require "mues/Events"
require "mues/filters/CommandShell"

module MUES
	class CommandShell

		### 'Loadenvironment' command
		class EngineShutdownCommand < AdminCommand

			### METHOD: initialize()
			### Initialize a new LoadEnvironmentCommand object
			def initialize
				@name			= 'shutdown'
				@synonyms		= %w{}
				@description	= 'Shut down the engine safely.'
				@usage			= 'shutdown'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the loadenvironment command, which generates a LoadEnvironmentEvent
			### with the environment specifications.
			def invoke( context, args )
				return [ OutputEvent.new( ">>> Shutting down the engine. <<<\n\n" ),
					EngineShutdownEvent.new( context.user ) ]
			end
			
		end # class EngineShutdownCommand

		### 'gc' Command
		class GcCommand < AdminCommand

			### METHOD: initialize()
			### Initialize a new LoadEnvironmentCommand object
			def initialize
				@name			= 'gc'
				@synonyms		= %w{}
				@description	= 'Start the garbage collector.'
				@usage			= 'gc'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the loadenvironment command, which generates a LoadEnvironmentEvent
			### with the environment specifications.
			def invoke( context, args )
				return [ OutputEvent.new( "Starting garbage collection.\n\n" ),
					GarbageCollectionEvent.new ]
			end
			
		end # class GcCommand

	end # class CommandShell
end # module MUES

