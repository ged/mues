#!/usr/bin/ruby
# 
# This file contains a collection of MUES::CommandShell::Command classes for
# interacting with MUES::Environment objects:
#
# [MUES::CommandShell::LoadEnvironmentCommand]
#	A command to instruct the MUES::Engine to load a MUES::Environment object.
#
# [MUES::CommandShell::UnloadEnvironmentCommand]
#	A command to instruct the MUES::Engine to unload a MUES::Environment object.
#
# [MUES::CommandShell::ListEnvironmentsCommand]
#	A command to fetch a list of the currently-loaded MUES::Environment objects
#	from the Engine.
#
# == Rcsid
# 
# $Id: environments.rb,v 1.3 2002/04/01 16:31:25 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#


require "mues"
require "mues/Exceptions"
require "mues/Events"
require "mues/filters/CommandShell"

module MUES
	class CommandShell

		### 'load' command
		class LoadEnvironmentCommand < AdminCommand

			### Initialize a new LoadEnvironmentCommand object
			def initialize # :nodoc:
				@name			= 'loadenv'
				@synonyms		= %w{}
				@description	= 'Load a environment object and make it available.'
				@usage			= 'loadenv <environment class> [as] <environment name>'

				super
			end

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


		### 'unload' Command
		class UnloadEnvironmentCommand < AdminCommand

			### Initialize a new UnloadEnvironmentCommand object
			def initialize # :nodoc:
				@name			= 'unloadenv'
				@synonyms		= %w{}
				@description	= 'Shut down and unload a loaded environment object.'
				@usage			= 'unloadenv <environment name>'

				super
			end

			### Invoke the unloadenvironment command, which generates a
			### UnloadEnvironmentEvent with the environment specifications.
			def invoke( context, args )
				unless args =~ %r{(\w+)}
					return OutputEvent.new( usage() )
				end

				return UnloadEnvironmentEvent.new( $1, context.user )
			end
		end


		### 'list' Command
		class ListEnvironmentsCommand < AdminCommand

			### Initialize a new UnloadEnvironmentCommand object
			def initialize # :nodoc:
				@name			= 'envlist'
				@synonyms		= %w{}
				@description	= 'List known environment classes which may be loaded.'
				@usage			= 'envlist'

				super
			end

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

