#!/usr/bin/ruby
# 
# This file contains a collection of administrative commands for controlling the
# MUES::Engine:
#
# [MUES::CommandShell::EngineShutdownCommand]
#	Command to instruct the Engine to shut down.
#
# [MUES::CommandShell::GcCommand]
#	Command to manually start the garbage-collector.
#
# == Rcsid
# 
# $Id: engine.rb,v 1.2 2002/04/01 16:31:25 deveiant Exp $
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

		### 'shutdown' Command
		class EngineShutdownCommand < AdminCommand

			### Initialize a new EngineShutdownCommandobject
			def initialize # :nodoc:
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

			### Initialize a new LoadEnvironmentCommand object
			def initialize # :nodoc:
				@name			= 'gc'
				@synonyms		= %w{}
				@description	= 'Start the garbage collector.'
				@usage			= 'gc'

				super
			end

			### Invoke the loadenvironment command, which generates a LoadEnvironmentEvent
			### with the environment specifications.
			def invoke( context, args )
				return [ OutputEvent.new( "Starting garbage collection.\n\n" ),
					GarbageCollectionEvent.new ]
			end
			
		end # class GcCommand

	end # class CommandShell
end # module MUES

