#!/usr/bin/ruby
# 
# This file contains the MUES::NullEnv class, a <strong>VERY</strong> simple
# testing MUES::Environment class.
# 
# This is a barebones environment used in testing. It doesn^t really contain any
# interesting functionality other than the ability to return roles and allow
# connections.
# 
# Well, maybe there^s a few other things you can do...
# 
# == Synopsis
# 
#   mues> /loadenv NullEnv nullWorld
#   Attempting to load the 'NullEnv' environment as 'nullWorld'
#   Successfully loaded 'nullWorld'
# 
#   mues> /roles
#   nullWorld (NullEnv):
#        muggle   A boring role for testing
#        admin    A barely less-boring role for testing
# 
#   (2) roles available to you.
# 
#   mues> /connect nullWorld superuser
#   Connecting...
#   Connected to NullEnvironment as 'superuser'
# 
#   nullWorld: superuser>> ...
# 
# == Rcsid
# 
# $Id: NullEnv.rb,v 1.6 2002/07/09 15:15:06 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Alexis Lee <red@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#


require "sync"

require "mues"
require "mues/Exceptions"
require "mues/Events"
require "mues/Environment"
require "mues/Role"
require "mues/IOEventFilters"

module MUES

	### A simple testing MUES::Environment class.
	class NullEnv < MUES::Environment

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: NullEnv.rb,v 1.6 2002/07/09 15:15:06 deveiant Exp $
		DefaultDescription = <<-"EOF"
		This is a barebones environment used in testing. It doesn^t really contain any
		interesting functionality other than the ability to return roles and allow
		connections.

		Well, maybe there^s a few other things you can do...
		EOF

		### Instantiate and return a new MUES::NullEnv object.
		def initialize( instanceName )
			super( instanceName, DefaultDescription )

			@participants		= []
			@participantsMutex	= Sync.new
		end


		######
		public
		######

		# The array of current participants
		attr_accessor :participants


		#
		# Methods required by the Environment class's contract:
		#

		### Start the world instance
		def start
			return MUES::LogEvent.new( "notice", "Starting Null environment #{self.muesid}" )
		end

		### Stop the world instance
		def stop
			# Stop participants
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
					

	end # class NullEnv
end # module MUES


