#!/usr/bin/ruby
###########################################################################
=begin 

=LoginSession.rb

== Name

LoginSession - A login session class

== Synopsis

  require "mues/LoginSession"
  requrie "mues/IOEventStream"
  require "mues/IOEventFilters"

  # ... later that night, in a SocketConnectEvent handler ...

  sock = event.socket
  sof = SocketOutputFilter.new( sock )

  ios = IOEventStream.new
  ios.addFilters( sof )

  loginHandler = LoginSession.new( config, ios )

== Description

This class encapsulates the task of authenticating a connecting player. It is
given a new IOEventStream for the connection, from which it gathers username and
password data, creating (({PlayerAuthenticationEvent}))s for each attempt. The
Engine, after determining if the authentication was valid, calls one of two
callbacks which are associated with the PlayerAuthenticationEvent -- one for a
successful login attempt, and one for a failed attempt.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "timeout"
require "thread"

require "mues/Namespace"
require "mues/Config"
require "mues/Exceptions"
require "mues/Debugging"
require "mues/Events"
require "mues/IOEventFilters"

module MUES
	class LoginSession < Object
		include Debuggable

		Version = %q$Revision: 1.2 $
		Rcsid = %q$Id: loginsession.rb,v 1.2 2001/05/22 04:33:19 deveiant Exp $

		### :TODO: Testing code only
		@@Logins = { 
			"ged"	=> { "password" => "testing", "isImmortal" => true },
			"guest" => { "password" => "guest", "isImmortal" => false },
		}

		### (PROTECTED) METHOD: initialize( aConfig, anIOEventStream, anIPAddrString )
		### Initialize a new login session object with the configuration,
		### IOEventStream, and IP address specified
		protected
		def initialize( aConfig, anIOEventStream, remoteHost )
			checkType( aConfig, MUES::Config )
			checkType( anIOEventStream, MUES::IOEventStream )

			super()

			# Set up instance variables, creating the login proxy we'll use to
			# get and send IOEvents to the stream
			@config				= aConfig
			@stream				= anIOEventStream
			@remoteHost			= remoteHost

			@loginAttemptCount	= 0
			@maxTries			= @config['login']['maxtries'].to_i

			@waitingOnEngine	= false
			@finished			= false
			@myProxy			= LoginProxy.new( self )
			@myTimeoutEvent		= nil
			@queuedInput		= []
			@currentLogin		= nil
			@authMutex			= Mutex.new

			@myProxy.debugLevel = 5
			@stream.addFilters( @myProxy )

			# Get the timeout from the config, and if there is one, create a
			# scheduled event to kill us after the timeout expires
			timeout = @config['login']['timeout'].to_i
			if timeout > 0 
				@myTimeoutEvent = LoginSessionFailureEvent.new( self, "Timeout (#{timeout} seconds)." )
				engine.scheduleEvents( Time.now + timeout, @myTimeoutEvent )
			end

			# Now queue the motd and the first username prompt output events
			@myProxy.queueOutputEvents( OutputEvent.new(@config["login"]["banner"]),
									    OutputEvent.new(@config["login"]["userprompt"]) )
		end
		
		#######################################################################
		###	P U B L I C   M E T H O D S
		#######################################################################
		public

		### METHOD: handleInputEvents( *events )
		### Get login and password information from input events
		def handleInputEvents( *newEvents )
			returnEvents = []

			_debugMsg( 3, "Handling input events." )
			
			# Combine the events we've been saving with the new ones and put
			# them through our little state-machine thingie.
			@authMutex.synchronize {
				events = ( @queuedInput | newEvents )
				@queuedInput.clear

				while ! events.empty?

					# If we've finished authentication and we're just waiting
					# around to be cleaned up, just return any events we're given.
					if @finished
						_debugMsg( 4, "Session is finished. Giving events back to caller." )
						returnEvents = events
						break

					# If we've waiting on a pending authevent, queue all events
					elsif @waitingOnEngine
						_debugMsg( 4, "Session is waiting on engine. Queueing events for later." )
						@queuedInput += events
						returnEvents.clear
						break

					# If we've not gotten a login yet, this event's data is the
					# login
					elsif ! @currentLogin
						ev = events.shift
						_debugMsg( 4, "Setting login name to '#{ev.data}'." )
						@currentLogin = ev.data
						@myProxy.queueOutputEvents( OutputEvent.new(@config["login"]["passprompt"]) )
						next

					# If we've got a login already, and we're not finished or
					# waiting for an auth event to return, then this input event
					# contains the password, so do authentication
					else
						ev = events.shift
						_debugMsg( 4, "Setting password to #{ev.data}, and dispatching a LoginSessionAuthEvent." )
						authEvent = LoginSessionAuthEvent.new( self,
															   @currentLogin,
															   ev.data,
															   @remoteHost,
															   method( :authSuccessCallback ),
															   method( :authFailureCallback ))
						authEvent.debugLevel = 3
						engine.dispatchEvents( authEvent )
						@waitingOnEngine = true
						@currentLogin = nil
					end
				end
			}

			return returnEvents
		end


		### METHOD: authSuccessCallback( player )
		### Callback for authentication success.
		def authSuccessCallback( player )
			_debugMsg( 1, "Player authenticated successfully." )

			@authMutex.synchronize {
				@finished = true
				@waitingOnEngine = false

				# Cancel the pending timeout
				if @myTimeoutEvent
					engine.cancelScheduledEvents( @myTimeoutEvent )
				end

				@stream.pause
				@stream.removeFilters( @myProxy )
				@stream.addInputEvents( *@queuedInputEvents )
			}

			PlayerLoginEvent.new( player, @stream )
		end


		### METHOD: authFailureCallback( reason )
		### Callback for authentication failure.
		def authFailureCallback( reason="None given" )
			_debugMsg( 1, "Login failed: #{reason}." )
			@loginAttemptCount += 1

			### After the number of tries specified in the login section of the
			### config, generate a login failure event to kill this session and
			### log the failure
			if @maxTries > 0 && @loginAttemptCount > @maxTries
				logMsg = "Max login tries exceeded for player '#{@login}'."
				_debugMsg( 1, logMsg )
				@myProxy.queueOutputEvents( OutputEvent.new(">>> Max tries exceeded. <<<") )
				return [ LoginSessionFailureEvent.new(self), LogEvent.new( logMsg ) ]


			### Prompt for login and try again
			else
				logMsg = "Failed login attempt #{@loginAttemptCount} for player '#{@login}'."
				_debugMsg( 1, logMsg )
				engine.dispatchEvents( LogEvent.new("notice", logMsg) )
				@myProxy.queueOutputEvents( OutputEvent.new(@config["login"]["userprompt"]) )

				@authMutex.synchronize {
					@currentLogin = nil
					@waitingOnEngine = false
				}

				return []
			end

		end


		### METHOD: terminate
		### Terminate the session and clean up
		def terminate
			_debugMsg( 1, "Terminating login session." )
			@authMutex.synchronize {
				@stream.shutdown if @stream
				@stream = nil

				# Cancel the timeout event if it hasn't fired yet
				if @myTimeoutEvent
					engine.cancelScheduledEvents( @myTimeoutEvent )
				end
			}
		end

	end # class LoginSession
end # module MUES

