#!/usr/bin/ruby
#################################################################
=begin

=NullEnvironment.rb

== Name

NullEnvironment - A VERY simple testing environment

== Synopsis

  mues> /load NullEnvironment
  Loading environment object from 'NullEnvironment' class...
  Environment loaded.

  mues> /roles
  NullEnvironment:
       testrole		A boring role for testing
       superuser	A barely less-boring role for testing

  (1) roles available to you.

  mues> /connect NullEnvironment superuser
  Connecting...
  Connected to NullEnvironment as 'superuser'

  mues {NullEnvironment:superuser}> ...

== Description

This is a barebones environment used in testing. It doesn^t really contain any
interesting functionality other than the ability to return roles and allow
connections.

Well, maybe there^s a few other things you can do...

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
	class NullEnvironment < Environment

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: NullEnv.rb,v 1.2 2001/07/30 09:51:36 deveiant Exp $
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

			proxy = Controller.new( user, Character.new(role), self )
			@participantsMutex.synchronize( SYNC::EX ) {
				@participants << proxy
			}

			return proxy
		end

		### METHOD: getAvailableRoles( aUser )
		### Get the roles in this environment which are available to the specified user.
		def getAvailableRoles( user )
			checkType( user, MUES::User )

			roles = [ Role.new( self, "schmoe", "An average schmoe participant" ) ]
			roles << Role.new( self, "admin", "Administrative participant" ) if user.is_admin?

			return roles
		end

		### 'Player' command support methods

		### METHOD: broadcast( message[, exception=MUES::NullEnv::Controller] )
		### Broadcast the specified message to all participants. If the
		### ((|exception|)) controller is specified, do not send the message to
		### the controller specified.
		def broadcast( message, exception=nil )
			checkType( message, ::String, OutputEvent )
			checkType( message, Controller )

			# Convert a string to output event
			if message.kind_of?( String )
				message = OutputEvent.new( message )
			end

			count = 0

			# Send the event to everyone connected, except perhaps the exception
			@participantsMutex.synchronize( Sync::SH ) {
				@participants.each {|part|
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
			userlist = " Connected users:"
			@participantsMutex.synchronize( Sync::SH ) {
				userList << @participants.sort.collect {|part|
					"%s: %s (%s)" % [
						part.user.to_s,
						part.character.role.name,
						part.character.role.description
					]
				}.join("\n")
			}
			userlist << "\n\n"

			return userlist
		end


		#############################################################
		###	S U B O R D I N A T E   W O R L D   C L A S S E S  
		#############################################################

		### The ParticipantProxy derivative (ie., controller) class
		class Controller < MUES::ParticipantProxy

			attr_reader :user, :character
			
			### METHOD: initialize( aUser=MUES::User, character=MUES::NullEnv::Character, env=MUES::NullEnv )
			### Initialize a new NullEnvironment::Controller object with the
			### specified user object.
			def initialize( user, character, env )
				super()

				@user = user
				@character = character
				@env = env
			end

			### METHOD: handleInputEvents( *events )
			### Handle input events from the IOEventStream
			def handleInputEvents( *events )
				results = []

				# Do some basic commands
				events.each {|evemt|
					case event.data

					# 'Who' command
					when /^who/
						results << OutputEvent.new( @env.getUserlist )

					# 'Say' command
					when /^say\s*(.*)/
						sayEvent = OutputEvent.new( "#{user.to_s} says: '#{$1}'" )
						@env.broadcast( sayEvent, self )
						results << OutputEvent.new( "You say: '#{$1}'" )

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
					

	end # class NullEnvironment
end # module MUES


