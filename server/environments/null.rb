#!/usr/bin/ruby
#################################################################
=begin

=NullEnv.rb

== Name

NullEnv - A VERY simple testing environment

== Synopsis

  mues> /loadenv NullEnv nullWorld
  Attempting to load the 'NullEnv' environment as 'nullWorld'
  Successfully loaded 'nullWorld'

  mues> /roles
  nullWorld (NullEnv):
       muggle   A boring role for testing
       admin    A barely less-boring role for testing

  (2) roles available to you.

  mues> /connect nullWorld superuser
  Connecting...
  Connected to NullEnvironment as 'superuser'

  nullWorld: superuser>> ...

== Description

This is a barebones environment used in testing. It doesn^t really contain any
interesting functionality other than the ability to return roles and allow
connections.

Well, maybe there^s a few other things you can do...

Red
To keep in sync with ObjectEnv, run this and check the resulting diff (nod):
cat NullEnv.rb | sed 's/Null/Object/g' | sed 's/nullWorld/objWorld/g' | diff -ub - ObjectEnv.rb > nod

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "sync"

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Events"
require "mues/Environment"
require "mues/Role"
require "mues/IOEventFilters"

module MUES
	class NullEnv < MUES::Environment

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: null.rb,v 1.4 2001/12/07 17:43:40 red Exp $
		DefaultName = "NullEnvironment"
		DefaultDescription = <<-"EOF"
		This is a barebones environment used in testing. It doesn^t really contain any
		interesting functionality other than the ability to return roles and allow
		connections.

		Well, maybe there^s a few other things you can do...
		EOF

		### (PROTECTED) METHOD: initialize()
		### Initialize the environment
		protected
		def initialize
			super( DefaultName, DefaultDescription )

			@participants		= []
			@participantsMutex	= Sync.new
		end

		#############################################################
		###	P U B L I C   M E T H O D S
		#############################################################
		public

		attr_accessor :participants

		### Methods required by the World class's contract

		### METHOD: start
		### Start the world instance
		def start
			return LogEvent.new( "notice", "Starting Null environment #{self.muesid}" )
		end

		### METHOD: stop
		### Stop the world instance
		def stop
			# Stop participants
			return LogEvent.new( "notice", "Stopping Null environment #{self.muesid}" )
		end

		### METHOD: getParticipantProxy( aUser=MUES::User, aRole=MUES::Role )
		### Return a (({MUES::ParticipantProxy})) object for the specified role
		### in the environment.
		def getParticipantProxy( user, role )
			checkType( user, MUES::User )
			checkType( role, MUES::Role )

			proxy = Controller.new( user, Character.new(role), role, self )
			@participantsMutex.synchronize( Sync::EX ) {
				@participants << proxy
			}

			return proxy
		end

		### METHOD: removeParticipantProxy( aProxy=MUES::NullEnv::Controller )
		### Remove the specified proxy from the environment's list of
		### participants, if it exists therein. Returns true on success, nil if
		### the specified proxy is not the correct type of controller, or false
		### if the specified proxy was not listed as a participant in this
		### environment.
		def removeParticipantProxy( aProxy )
			return nil unless aProxy.kind_of? MUES::NullEnv::Controller

			return false unless @participants & [ aProxy ]
			@participants -= [ aProxy ]
			return true
		end

		### METHOD: getAvailableRoles( aUser )
		### Get the roles in this environment which are available to the specified user.
		def getAvailableRoles( user )
			checkType( user, MUES::User )

			roles = [ Role.new( self, "muggle", "An average schmoe participant" ) ]
			roles << Role.new( self, "admin", "Administrative participant" ) if user.isAdmin?

			return roles
		end

		### 'Player' command support methods

		### METHOD: broadcast( message[, exception=MUES::NullEnv::Controller] )
		### Broadcast the specified message to all participants. If the
		### ((|exception|)) controller is specified, do not send the message to
		### the controller specified.
		def broadcast( message, exception=nil )
			checkType( message, ::String, OutputEvent )
			checkType( exception, Controller )

			# Convert a string to output event
			if message.kind_of?( String )
				message = OutputEvent.new( message )
			end

			count = 0

			# Send the event to everyone connected, except perhaps the exception
			@participantsMutex.synchronize( Sync::SH ) {
				@participants.each {|part|
					next if part == exception
					part.queueOutputEvents( message )
					count += 1
				}
			}

			return count
		end

		### METHOD: getUserlist
		### Return a string listing the connected users, suitable for the 'who' command
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
		###	S U B O R D I N A T E   W O R L D   C L A S S E S  
		#############################################################

		### The ParticipantProxy derivative (ie., controller) class
		class Controller < MUES::ParticipantProxy

			DefaultSortPosition = 750

			# Red: user already has an attr_reader in ParticipantProxy
			attr_reader :user, :character
			
			### METHOD: initialize( aUser=MUES::User,
			###						character=MUES::NullEnv::Character, 
			###						role=MUES::Role,
			###						env=MUES::NullEnv )
			### Initialize a new NullEnv::Controller object with the
			### specified user object.
			def initialize( user, character, role, env )
				super( user, role, env )
				@character = character
			end

			### METHOD: handleInputEvents( *events )
			### Handle input events from the IOEventStream
			def handleInputEvents( *events )
				results = []

				# Do some basic commands
				events.each {|event|
					case event.data

					# 'Who' command
					when /^who/
						queueOutputEvents( OutputEvent.new(@env.getUserlist) )

					# 'Say' command
					when /^say\s*(.*)/
						sayEvent = OutputEvent.new( "#{user.to_s} says: '#{$1}'\n\n" )
						@env.broadcast( sayEvent, self )
						queueOutputEvents( OutputEvent.new("You say: '#{$1}'\n\n") )

					else
						results << event

					end
				}

				return results
			end

		end # class Controller


		# Rudimentary character object. It doesn't really do much but hold the
		# role object and take up memory currently.
		class Character < MUES::Object

			attr_reader :role

			### METHOD: initialize( role=MUES::Role )
			### Intialize the character object with the specified role object
			def initialize( role )
				checkType( role, MUES::Role )

				super()
				@role = role
			end
		end
					

	end # class NullEnv
end # module MUES


