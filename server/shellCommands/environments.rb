#!/usr/bin/ruby
#################################################################
=begin

=environments.rb

== Name

environments - Environment administrative commands

== Description

This module is a collection of environment manipulation and administrative commands
for the MUES command shell.

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
require "mues/Events"
require "mues/filters/CommandShell"

module MUES
	class CommandShell

		### 'Loadenvironment' command
		class LoadEnvironmentCommand < AdminCommand

			### METHOD: initialize()
			### Initialize a new LoadEnvironmentCommand object
			def initialize
				@name			= 'loadenv'
				@synonyms		= %w{}
				@description	= 'Load a environment object and make it available.'
				@usage			= 'loadenv <environment class> [as] <environment name>'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the loadenvironment command, which generates a LoadEnvironmentEvent
			### with the environment specifications.
			def invoke( context, args )
				unless args =~ %r{(\w+)\s+(?:as\s+)?(\w+)}
					return OutputEvent.new( usage() )
				end

				return [ OutputEvent.new( "Attempting to load the '#{$1}' environment as '#{$2}'\n" ),
					LoadEnvironmentEvent.new( $2, $1, context.user ) ]
			end
			
		end # class LoadEnvironmentCommand

		class UnloadEnvironmentCommand < AdminCommand

			### METHOD: initialize()
			### Initialize a new UnloadEnvironmentCommand object
			def initialize
				@name			= 'unloadenv'
				@synonyms		= %w{}
				@description	= 'Shut down and unload a loaded environment object.'
				@usage			= 'unloadenv <environment name>'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the unloadenvironment command, which generates a
			### UnloadEnvironmentEvent with the environment specifications.
			def invoke( context, args )
				unless args =~ %r{(\w+)}
					return OutputEvent.new( usage() )
				end

				return UnloadEnvironmentEvent.new( $1, context.user )
			end
		end

		class ListEnvironmentsCommand < AdminCommand

			### METHOD: initialize()
			### Initialize a new UnloadEnvironmentCommand object
			def initialize
				@name			= 'envlist'
				@synonyms		= %w{}
				@description	= 'List known environment classes which may be loaded.'
				@usage			= 'envlist'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Create an output event with a list of the loaded environments.
			def invoke( context, args )
				output = "\nAvailable MUES Environment classes:\n\t"
				list = MUES::Environment.listEnvClasses
				if list.empty?
					output << "(None)"
				else
					output << list.join("\n\t")
				end
				output << "\n"

				return OutputEvent.new( output )
			end
		end # class ListEnvironmentsCommand

	end # class CommandShell
end # module MUES

