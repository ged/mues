#!/usr/bin/ruby
###########################################################################
=begin

=status.rb

== Name

status - Server status command classes

== Description

This module is a collection of server status command classes for the MUES
command shell. It is loaded by the MUES::CommandShell::Command class.

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

		### 'Status' command
		class StatusCommand < CreatorCommand

			### METHOD: initialize()
			### Initialize a new StatusCommand object
			def initialize
				@name				= 'status'
				@synonyms			= %w{}
				@description		= 'Check internal server status.'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the status command, which generates an output event with
			### the server's status information.
			def invoke( context, args )
				return OutputEvent.new( engine.statusString )
			end

		end # class StatusCommand


 		### 'Threads' command
		class ThreadsCommand < ImplementorCommand

			### METHOD: initialize()
			### Initialize a new ThreadsCommand object
			def initialize
				@name				= 'threads'
				@synonyms			= %w{}
				@description		= 'Display server threads table.'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the threads command
			def invoke( context, args )
				thrList = "#{Thread.list.length} running threads:\n\n" <<
					"\t%11s  %-4s  %-5s  %-5s  %-5s %-20s\n" % %w{Id Prio State Safe Abort Description}

				Thread.list.each {|t|
					thrList << "\t%11s  %-4d  %-5s  %-4d   %-5s %-20s\n" % [
						t.id,
						t.priority,
						t.status,
						t.safe_level,
						t.abort_on_exception ? "t" : "f",
						t.desc
					]
				}
				thrList << "\n"
				return OutputEvent.new(thrList)
			end

		end # class ThreadsCommand


 		### 'Objects' command
		class ObjectsCommand < ImplementorCommand

			### METHOD: initialize()
			### Initialize a new ObjectsCommand object
			def initialize
				@name				= 'objects'
				@synonyms			= %w{}
				@description		= 'Display server objectspace table.'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the objects command
			def invoke( context, args )
				objectList = []
				ObjectSpace.each_object( MUES::Object ) {|obj| objectList << obj}

				objectTable = "#{objectList.length} active MUES objects:\n\n" <<
					"\t        Id  Class                          Frozen  Tainted\n"
				
				objectList.each {|obj|
					objectTable << "\t%10d  %-30s   %1s      %1s\n" % [
						obj.id,
						obj.class.name,
						obj.frozen? ? "y" : "n",
						obj.tainted? ? "y" : "n"
					]
				}
				objectTable << "\n"
				return OutputEvent.new(objectTable)
			end

		end # class ObjectsCommand
		
	end # class CommandShell
end # module MUES

