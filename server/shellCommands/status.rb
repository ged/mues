#!/usr/bin/ruby
# 
# This file contains a collection of MUES::CommandShell::Command classes for
# viewing the status of various parts of the MUES::Engine:
#
# [MUES::CommandShell::StatusCommand]
#	Command to fetch and display the Engine status.
#
# [MUES::CommandShell::ThreadsCommand]
#	Command to display the thread status table.
#
# [MUES::CommandShell::ObjectsCommand]
#	Command to display a table of all active MUES objects.
#
# [MUES::CommandShell::PrintObjectCommand]
#	Command to inspect a MUES object by id.
#
# [MUES::CommandShell::FiltersCommand]
#	Command to 
# 
# == Rcsid
# 
# $Id: status.rb,v 1.5 2002/04/01 16:31:24 deveiant Exp $
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

require "pp"

require "mues"
require "mues/Exceptions"
require "mues/Events"
require "mues/filters/CommandShell"

module MUES
	class CommandShell

		### 'status' command
		class StatusCommand < CreatorCommand

			### Initialize a new StatusCommand object
			def initialize # :nodoc:
				@name				= 'status'
				@synonyms			= %w{}
				@description		= 'Check internal server status.'

				super
			end

			### Invoke the status command, which generates an output event with
			### the server's status information.
			def invoke( context, args )
				return OutputEvent.new( engine.statusString )
			end

		end # class StatusCommand


 		### 'threads' command
		class ThreadsCommand < ImplementorCommand

			### Initialize a new ThreadsCommand object
			def initialize # :nodoc:
				@name				= 'threads'
				@synonyms			= %w{}
				@description		= 'Display server threads table.'

				super
			end

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

			### Initialize a new ObjectsCommand object
			def initialize # :nodoc:
				@name				= 'objects'
				@synonyms			= %w{}
				@description		= 'Display server objectspace table.'

				super
			end

			### Invoke the objects command
			def invoke( context, args )
				objectList = []
				ObjectSpace.each_object( MUES::Object ) {|obj| objectList << obj}

				objectTable = "#{objectList.length} active MUES objects:\n\n" <<
					"\t        Id  Class                          Frozen  Tainted\n"
				
				objectList.sort {|a,b|
					(a.class.name <=> b.class.name).nonzero? || a.id <=> b.id
				}.each {|obj|
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


 		### 'printobject' command
		class PrintObjectCommand < ImplementorCommand

			### Initialize a new ObjectsCommand object
			def initialize
				@name				= 'printobject'
				@synonyms			= %w{pp}
				@description		= 'Prettyprint an object.'
				@usage				= 'printobject <objectId>'

				super
			end

			### Invoke the printobject command
			def invoke( context, args ) # :nodoc:
				unless args =~ /^\s*(\d+)\s*$/
					return OutputEvent.new( usage() )
				end

				targetId = $1.to_i
				targetObject = nil
				prettyPrinted = []

				ObjectSpace.each_object( MUES::Object ) {|obj|
					next unless obj.id == targetId
					targetObject = obj
					break 
				}
				return OutputEvent.new( "No object found with id '#{targetId}'.\n\n" ) if
					targetObject.nil?

				PP.pp( targetObject, 79, prettyPrinted )

				return OutputEvent.new(prettyPrinted.join('') + "\n\n")
			end

		end # class PrintObjectCommand


 		### 'filters' command
		class FiltersCommand < ImplementorCommand

			### Initialize a new FiltersCommand object
			def initialize
				@name				= 'filters [<username>]'
				@synonyms			= %w{}
				@description		= "Display a user's event filters."

				super
			end

			### Invoke the filters command
			def invoke( context, args ) # :nodoc:
				if args.empty?
					user = context.user
				elsif args =~ /^\s*(\w+)\s*$/
					user = engine.getUserByName( $1 ) 
					if user.nil?
						return OutputEvent.new( "No such user '#$1'" )
					end
				else
					return OutputEvent.new( usage() )
				end

				filterList = [ "Filters currently in your stream:" ]
				user.ioEventStream.filters.sort.each {|filter|
					filterList << filter.to_s
				}
				return OutputEvent.new( filterList.join("\n\t") + "\n" )
			end

		end # class ObjectsCommand

	end # class CommandShell
end # module MUES

