#!/usr/bin/ruby
#
# This file contains the MUES::LoginSession class, which encapsulates the task
# of authenticating a connecting user. It is given a new IOEventStream for the
# connection. It gathers username and password data from the IOEventStream
# through a MUES::LoginProxy object, creating UserAuthenticationEvents for each
# attempt.
#
# The Engine, after determining the authentication was valid, calls one of two
# callbacks which are associated with the UserAuthenticationEvent -- one for a
# successful login attempt, and one for a failed attempt.
#
# == Synopsis
# 
#   require 'mues/loginsession'
#   require 'mues/ioeventstream'
#   require 'mues/ioeventfilters'
# 
#   # ... later that night, in a SocketConnectEvent handler ...
# 
#   sock = event.socket
#   sof = SocketOutputFilter.new( sock )
# 
#   ios = IOEventStream.new
#   ios.addFilters( sof )
# 
#   loginHandler = LoginSession.new( config, ios )
# 
#
# == Rcsid
# 
# $Id: loginsession.rb,v 1.20 2003/10/13 04:02:16 deveiant Exp $
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

require "timeout"
require "thread"

require 'mues/object'
require 'mues/config'
require 'mues/exceptions'
require 'mues/events'
require 'mues/ioeventfilters'

module MUES

	### Login session class: encapsulates the task of authenticating a user.
	class LoginSession < Object; implements MUES::Debuggable

		include MUES::TypeCheckFunctions,
			MUES::ServerFunctions,
			MUES::FactoryMethods,
			MUES::UtilityFunctions

		Version = /([\d\.]+)/.match( %q{$Revision: 1.20 $} )[1]
		Rcsid = %q$Id: loginsession.rb,v 1.20 2003/10/13 04:02:16 deveiant Exp $

		# Pattern for untainting user input for username and password
		LoginUntaintPattern		= %r{([a-z]\w+)}
		PasswordUntaintPattern	= %r{([\x20-\x7e]+)}


		### Create and initialize a new login session object with the
		### <tt>config</tt> (MUES::Config object), <tt>stream</tt>
		### (MUES::IOEventStream object), and <tt>outputFilter</tt> specified.
		def initialize( config, stream, outputFilter )
			checkType( config, MUES::Config )
			checkType( stream, MUES::IOEventStream )
			checkType( outputFilter, MUES::OutputFilter )

			super()

			delegator = MUES::EventDelegator::new( self, :handleInputEvents, false )

			# Set up instance variables, creating the login proxy we'll use to
			# get and send IOEvents to the stream
			@config				= config
			@stream				= stream
			@outputFilter		= outputFilter

			@loginAttemptCount	= 0
			@maxTries			= @config.login.maxtries

			@waitingOnEngine	= false
			@finished			= false
			@delegator			= delegator
			@timeoutEvent		= nil
			@queuedInput		= []
			@currentLogin		= nil
			@authMutex			= Mutex.new

			@stream.addFilters( delegator )

			# Get the timeout from the config, and if there is one, create a
			# scheduled event to kill us after the timeout expires
			timeout = @config.login.timeout
			if timeout > 0 
				@timeoutEvent = MUES::LoginSessionFailureEvent::
					new( self, "Timeout (#{timeout} seconds)." )
				scheduleEvents( Time.now + timeout, @timeoutEvent )
			end

			banner = @config.login.banner.gsub( /^[ \t]+/s, '' )
			userprompt = @config.login.userprompt

			# Now queue the login banner and the first username prompt output
			# events
			delegator.queueOutputEvents( MUES::OutputEvent::new(banner),
										 MUES::PromptEvent::new(userprompt) )
		end
		

		######
		public
		######

		# The number of login attempts that have been tried already
		attr_reader :loginAttemptCount

		# The maximum number of login attempts that will be allowed by this session
		attr_reader :maxTries



		### Returns the peerName of the connecting MUES::OutputFilter.
		def peerName
			@outputFilter.peerName
		end
		deprecate_method :remoteHost, :peerName
		

		### InputEvent handler: Get login and password information from input
		### events.
		def handleInputEvents( delegator, *newEvents )
			returnEvents = []

			debugMsg( 3, "Handling input events." )
			
			# Combine the events we've been saving with the new ones and put
			# them through our little state-machine thingie.
			@authMutex.synchronize {
				events = ( @queuedInput | newEvents )
				@queuedInput.clear

				while ! events.empty?

					# If we've finished authentication and we're just waiting
					# around to be cleaned up, just return any events we're given.
					if @finished
						debugMsg 4, "Session is finished. Giving events back to caller."
						returnEvents = events
						break

					# If we've waiting on a pending authevent, queue all events
					elsif @waitingOnEngine
						debugMsg 4, "Session is waiting on engine. Queueing events for later."
						@queuedInput += events
						returnEvents.clear
						break

					# If we've not gotten a login yet, this event's data is the
					# login
					elsif ! @currentLogin
						login = untaintString( events.shift.data, LoginUntaintPattern ).to_s
						debugMsg( 4, "Setting login name to '#{login}'." )
						@currentLogin = login
						event = HiddenInputPromptEvent::new( @config.login.passprompt )
						@delegator.queueOutputEvents( event )
						next

					# If we've got a login already, and we're not finished or
					# waiting for an auth event to return, then this input event
					# contains the password, so do authentication
					else
						pass = untaintString( events.shift.data, PasswordUntaintPattern ).to_s

						debugMsg 4, "Setting password to '#{pass}', and dispatching " \
							"a LoginSessionAuthEvent."
						authEvent = MUES::LoginSessionAuthEvent::new self,
							@currentLogin,
							pass,
							@outputFilter,
							method( :authSuccessCallback ),
							method( :authFailureCallback )
						authEvent.debugLevel = 3
						dispatchEvents( authEvent )
						@waitingOnEngine = true
						@currentLogin = nil
					end
				end
			}

			return returnEvents
		end


		### Callback for authentication success. Called by the MUES::Engine
		### after the +user+ successfully authenticates. 
		def authSuccessCallback( user )
			debugMsg( 1, "User authenticated successfully." )

			stream = nil
			@authMutex.synchronize {
				@finished = true
				@waitingOnEngine = false

				# Cancel the pending timeout
				if @timeoutEvent
					cancelScheduledEvents( @timeoutEvent )
				end

				@stream.pause
				@stream.stopFilters( @delegator )
				@stream.addInputEvents( *@queuedInputEvents )
				stream = @stream

				# Clear up circular references
				@delegator = nil
				@stream = nil
				@timeoutEvent = nil
			}

			UserLoginEvent.new( user, stream, self )
		end


		### Callback for authentication failure. Called by the MUES::Engine when
		### the user fails to authenticate for the specified +reason+ (a
		### String).
		def authFailureCallback( reason="None given" )
			debugMsg( 1, "Login failed: #{reason}." )
			@loginAttemptCount += 1

			@delegator.queueOutputEvents( OutputEvent.new("\nAuthentication failure.\n") )

			### After the number of tries specified in the login section of the
			### config, generate a login failure event to kill this session and
			### log the failure
			if @maxTries > 0 && @loginAttemptCount >= @maxTries
				self.log.notice( "Max login tries exceeded for session #{self.id} from #{@remoteHost}." )
				@delegator.queueOutputEvents( OutputEvent.new(">>> Max tries exceeded. <<<") )
				return [ LoginSessionFailureEvent.new(self,"Too many attempts") ]


			### Prompt for login and try again
			else
				self.log.notice( "Failed login attempt #{@loginAttemptCount} from #{@remoteHost}." )
				@delegator.queueOutputEvents( OutputEvent.new("\n" + @config.login.userprompt) )

				@authMutex.synchronize {
					@currentLogin = nil
					@waitingOnEngine = false
				}

				return []
			end

		end


		### Terminate the session and clean up.
		def terminate
			debugMsg( 1, "Terminating login session." )
			@authMutex.synchronize {
				@stream.shutdown if @stream
				@stream = nil

				# Cancel the timeout event if it hasn't fired yet
				if @timeoutEvent
					cancelScheduledEvents( @timeoutEvent )
				end

				# Clear up circular references
				@delegator = nil
				@stream = nil
				@timeoutEvent = nil
			}
		end

	end # class LoginSession
end # module MUES

