#!/usr/bin/ruby
###########################################################################
=begin

=LoginProxy.rb

== Name

LoginProxy - A login proxy class for IOEventStreams

== Synopsis

  require "mues/filters/LoginProxy"

== Description

Instances of this class are used in IOEventStreams to do authentication and
login for a player.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/Debugging"
require "mues/Player"
require "mues/Config"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

module MUES
	class LoginProxy < IOEventFilter
		include Debuggable
		
		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: LoginProxy.rb,v 1.1 2001/03/29 02:34:27 deveiant Exp $

		@@DefaultSortPosition = 600

		### :TODO: Testing code only
		@@Logins = { 
			"ged"	=> { "password" => "testing", "isImmortal" => true },
			"guest" => { "password" => "guest", "isImmortal" => false },
		}

		### Public methods
		public

		### Accessors
		attr_accessor :cachedInput, :cachedOutput, :initTime, :player, :login

		### METHOD: initialize( aConfig )
		### Initialize a new login input filter object
		def initialize( aConfig, aPlayer )
			unless $0 == __FILE__ then
				checkType( aConfig, Config )
				checkType( aPlayer, Player )

				@config				= aConfig
				@player				= aPlayer
				@cachedInput		= []
				@cachedInputMutex	= Mutex.new
				@cachedOutput		= []
				@cachedOutputMutex	= Mutex.new
				@initTime			= Time.now
				@tries				= 0
				@login				= nil

				super()
				self.queueOutputEvents( OutputEvent.new(@config["login"]["banner"]),
									    OutputEvent.new(@config["login"]["userprompt"]) )
			else
				super()
			end
		end

		### METHOD: loginSucceed( player )
		### Callback for login success.
		def loginSucceed( player )
		end

		### METHOD: loginFailure( player, message )
		def loginFailure( player, message )
		end
		
		### METHOD: handleInputEvents( *events )
		### Handle all input until the user has satisfied login requirements, then
		### pass all input to upstream handlers.
		### :TODO: Most of this stuff will need to be modified to access the player
		### database once that's working.
		def handleInputEvents( *events )
			if @isFinished then
				return super( events )
			end

			returnEvents = []
			_debugMsg( 1, "LoginProxy: Handling #{returnEvents.size} input events." )

			### Check to see if login has timed out
			if ( Time.now - @initTime >= @config["login"]["timeout"].to_f ) then
				_debugMsg( 1, "Login has timed out." )
				queueOutputEvents( OutputEvent.new( ">>> Timed out <<<" ) )
				engine.dispatchEvents( PlayerLoginFailureEvent.new(@player, "Timeout.") )
				
			else

				### :TODO: Modify this to use asynchronous events to
				### authenticate instead of a state-machine thingie with
				### synchronous calls to the engine.

				### Iterate over each input event, checking username/password
				events.flatten.each do |event|

					_debugMsg( 1, "Processing input event '#{event.to_s}'" )

					### If we're finished logging in, add any remaining events to
					### the cached input events
					if @isFinished then
						returnEvents.push( event )
						next
					end

					### If the login hasn't been set yet, fill it in and move on to the next
					if ! @login then
						_debugMsg( 1, "Setting login to '#{event.data}'." )
						@login = event.data
						queueOutputEvents( OutputEvent.new(@config["login"]["passprompt"]) )

						### If there's a player by the name specified, and the password
						### matches, then log the player in
					elsif _authenticatePlayer( @login, event.data ) then
						_debugMsg( 1, "Player authenticated successfully." )
						@player.name = @login
						@player.isImmortal = @@Logins[ @login ]["isImmortal"]

						queueOutputEvents( OutputEvent.new("Logged in.\n\n"), OutputEvent.new(@player.prompt) )
						engine.dispatchEvents( PlayerLoginEvent.new(@player) )
						@isFinished = true

						### Otherwise, they failed
					else
						_debugMsg( 1, "Login failed." )
						@tries += 1

						### Only allow a certain number of tries
						if @config["login"]["maxtries"].to_i > 0 && @tries > @config["login"]["MaxTries"].to_i then
							_debugMsg( 1, "Max login tries exceeded." )
							queueOutputEvents( OutputEvent.new(">>> Max tries exceeded. <<<") )
							engine.dispatchEvents( PlayerLoginFailureEvent.new(@player) )
						else
							_debugMsg( 1, "Failed login attempt #{@tries} for player '#{@login}'." )
							logMsg = "Failed login attempt #{@tries} for player '#{@login}'."
							engine.dispatchEvents( LogEvent.new("notice", logMsg) )
							queueOutputEvents( OutputEvent.new(@config["login"]["userprompt"]) )
						end

						@login = nil
					end
				end
			end

			return [ returnEvents ].flatten
		end


		### METHOD: handleOutputEvents( *events )
		### Cache and squelch all output
		def handleOutputEvents( *events )
			events.flatten!
			checkEachType( events, OutputEvent )

			@cachedOutputMutex.synchronize {
				@cachedOutput += events
			}

			_debugMsg( 1, "I have #{@queuedOutputEvents.length} pending output events." )
			ev = super()
			ev.flatten!
			_debugMsg( 1, "Parent class's handleOutputEvents() returned #{ev.size} events." )

			return ev
		end


	end # class LoginProxy
end # module MUES
