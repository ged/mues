#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectEnvironment class - A MUES::Environment derivative
# for testing metaclass code.
# 
# == Synopsis
# 
#   mues> /loadenv ObjectEnvironment objWorld
#   Attempting to load the 'ObjectEnvironment' environment as 'objWorld'
#   Successfully loaded 'objWorld'
# 
#   mues> /roles
#   objWorld (ObjectEnvironment):
#        tester		An object-testing role
# 
#   (1) role available to you.
# 
#   mues> /connect objWorld tester
#   Connecting...
#   Connected to ObjectEnvironment as 'tester'
# 
#   objWorld: tester {nil}>> ...
# 
# == Subversion ID
# 
# $Id$
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

require "sync"

require "mues"
require 'mues/environment'
require 'mues/classlibrary'
require 'mues/objectspacevisitor'

module MUES

	### A MUES metaclass testing environment class. It is a derivative of the
	### MUES::Environment class.
	class ObjectEnvironment < MUES::Environment


		### Forward declarations
		class Visitor < MUES::ObjectSpaceVisitor ; end
		class Character < MUES::Object ; end
		class Controller < MUES::ParticipantProxy ; end


		### Class constants
		# Version information

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# The default name of instances of this environment
		DefaultName = "ObjectEnvironment"

		# The default description associated with instances of this environment.
		DefaultDescription = <<-"EOF"
		A metaclass testing environment.
		EOF

		# The default arguments to give when creating a MUES::ObjectStore
		DefaultObjectStoreArgs = {
			:backend	=> 'Flatfile',
			:memmgr		=> 'Simple',
			:visitor	=> MUES::ObjectEnvironment::Visitor,
			:indexes	=> [:class],
		}


		### Create and return a new object environment.
		def initialize( instanceName, desc=DefaultDescription, params, ostore )
			super( instanceName, desc, params, ostore )

			@participants		= []
			@participantsMutex	= Sync.new

			@classLibrary		= nil
			@objectStore		= nil
		end


		######
		public
		######

		# The Array of current participants
		attr_accessor :participants


		### Start the world instance
		def start

			# Create the objectstore
			unless @objectStore
				self.log.notice( "Creating objectstore for '#{self.name}' environment" )
				args = DefaultObjectStoreArgs
				args[:name] = self.name
				@objectStore = MUES::ObjectStore::create( args )
			end

			# Load/create the metaclass library
			@classLibrary = MUES::ClassLibrary::new( self.name, @objectStore )

			# Queue up events to load the adapter for the objectstore, and a
			# logging event.
			return [
				osAdapterEvent
			]
		end


		### Stop the world instance
		def stop
			@objectStore.close
			@objectStore = nil
			
			# Stop participants

			# Return a logging event
			return MUES::LogEvent.new( "notice", "Stopping Null environment #{self.muesid}" )
		end


		### Return a MUES::ParticipantProxy object for the specified +user+ and
		### +role+ in the environment.
		def getParticipantProxy( user, role )
			checkType( user, MUES::User )
			checkType( role, MUES::Role )

			proxy = MUES::NullEnv::Controller.new( user, MUES::NullEnv::Character.new(role), role, self )
			@participantsMutex.synchronize( Sync::EX ) {
				@participants << proxy
			}

			return proxy
		end


		### Remove the specified MUES::ParticipantProxy from the environment's
		### list of participants, if it exists therein. Returns true on success,
		### nil if the specified proxy is not the correct type of controller, or
		### false if the specified proxy was not listed as a participant in this
		### environment.
		def removeParticipantProxy( aProxy )
			return nil unless aProxy.kind_of? MUES::NullEnv::Controller

			return false unless @participants & [ aProxy ]
			@participants -= [ aProxy ]
			return true
		end


		### Get the roles in this environment which are available to the
		### specified user. Returns an array of MUES::Role objects.
		def getAvailableRoles( user )
			checkType( user, MUES::User )

			roles = [ MUES::Role.new( self, "muggle", "An average schmoe participant" ) ]
			roles << MUES::Role.new( self, "admin", "Administrative participant" ) if user.isAdmin?

			return roles
		end


		#
		# 'Player' command support methods:
		#

		### Broadcast the specified +message+ to all participants. If
		### <tt>except</tt> is specified, do not send the message to the
		### MUES::NullEnv::Controller specified.
		def broadcast( message, except=nil )
			checkType( message, ::String, MUES::OutputEvent )
			checkType( except, MUES::NullEnv::Controller )

			# Convert a string to output event
			if message.kind_of?( String )
				message = MUES::OutputEvent.new( message )
			end

			count = 0

			# Send the event to everyone connected, except perhaps the exception
			@participantsMutex.synchronize( Sync::SH ) {
				@participants.each {|part|
					next if part == except
					part.queueOutputEvents( message )
					count += 1
				}
			}

			return count
		end


		### Return a string listing the connected users, suitable for the 'who' command.
		def getUserlist

			# Iterate over the list of connected users, adding a line for each
			# of 'em
			userList = " Connected users:\n"
			@participantsMutex.synchronize( Sync::SH ) {
				userList << @participants.sort.collect {|part|
					"  %s [played by %s]" % [
						part.character.role.name,
						part.user.username,
					]
				}.join("\n")
			}
			userList << "\n\n"

			return userList
		end


		#############################################################
		###	I N N E R   C L A S S E S
		#############################################################

		### The MUES::ParticipantProxy derivative (ie., controller) class for
		### the MUES::NullEnv testing Environment.
		class Controller < MUES::ParticipantProxy

			DefaultSortPosition = 750


			### Create and return a new Controller object with the specified
			### MUES::User, MUES::NullEnv::Character, MUES::Role, and
			### MUES::NullEnv objects.
			def initialize( user, character, role, env )
				super( user, role, env )
				@character = character
			end

			
			######
			public
			######

			# The associated character object
			attr_reader :character
			

			### Handle input events from the IOEventStream
			def handleInputEvents( *events )
				results = []

				# Do some basic commands
				events.each {|event|
					case event.data

					# 'Who' command
					when /^who/
						queueOutputEvents( MUES::OutputEvent.new(@env.getUserlist) )

					# 'Say' command
					when /^say\s*(.*)/
						sayEvent = MUES::OutputEvent.new( "#{user.to_s} says: '#{$1}'\n\n" )
						@env.broadcast( sayEvent, self )
						queueOutputEvents( MUES::OutputEvent.new("You say: '#{$1}'\n\n") )

					else
						results << event

					end
				}

				return results
			end

		end # class Controller



		### Rudimentary character object class for MUES::NullEnv
		### environments. It doesn't really do much but hold a role object and
		### take up memory currently.
		class Character < MUES::Object

			### Create and return a new character object with the specified role
			### (a MUES::Role object).
			def initialize( role )
				checkType( role, MUES::Role )

				super()
				@role = role
			end


			######
			public
			######

			# The MUES::Role associated with this Character.
			attr_reader :role

		end
					
		
		### The visitor class that can be used to traverse the objectspace of
		### instances of this world.
		class Visitor < MUES::ObjectSpaceVisitor

			### This will obviously have to be fleshed out when I figure out how
			### the visitor is going to work.
			def visit ; end

		end
		

	end # class ObjectEnvironment
end # module MUES


