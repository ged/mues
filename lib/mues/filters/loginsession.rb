#!/usr/bin/ruby
# 
# This file contains the MUES::LoginSession class, a derivative of
# MUES::IOEventFilter. This filter encapsulates the login sequence, prompting
# connecting users for authentication/authorization information. It's meant to
# be subclassed by environment authors, though it does provide simple login
# functionality on its own.
# 
# == Synopsis
# 
#   
# 
# == Subversion Id
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
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'pluginfactory'
require 'sync'

require 'timeout'
require 'mues/mixins'
require 'mues/object'
require 'mues/events'
require 'mues/filters/ioeventfilter'


module MUES

	### This filter encapsulates the login sequence, prompting connecting users
	### for authentication/authorization information. It's meant to be
	### subclassed by environment authors, though it does provide simple login
	### functionality on its own.
	class LoginSession < MUES::IOEventFilter

		include PluginFactory,
			MUES::ServerFunctions,
			MUES::UtilityFunctions

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# Default filter sort order number (See MUES::IOEventFilter)
		DefaultSortPosition = 610

		# Default configuration parameters
		DefaultParams = {
			:banner 	=> "\n>-- MUES --<\n",
			:timeout 	=> 600,
			:userPrompt => 'Username: ',
			:passPrompt => 'Password: ',
			:maxTries 	=> 3,
		}

		# Untainting pattern for username input
		UsernameUntaintPattern = %r{([a-z]\w+)}

		# Untainting pattern for password input
        PasswordUntaintPattern = %r{([\x20-\x7e]+)}


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new LoginSession object.
		def initialize( peerName, params={} )
			@peerName			= peerName

			params = DefaultParams.merge( params )
			@banner				= params[:banner].gsub( /^[ \t]+/s, '' )
			@userPrompt			= params[:userPrompt]
			@passPrompt			= params[:passPrompt]
			@maxTries			= params[:maxTries]
			@timeout			= params[:timeout]
			
			@queuedInput		= []
			@authMutex			= Sync::new
			@timeoutEvent		= nil
			@stream				= nil
			@user				= nil

			@waitingOnEngine	= false
			@loginAttemptCount	= 0
			@username			= nil

			super()
		end


		######
		public
		######

		# The name of the connecting host/device
		attr_reader :peerName


		### Start the filter in the specified +stream+. Overridden from
		### IOEventFilter.
		def start( stream )
			self.log.debug "Login session 0x%0x starting." %
				[ self.object_id * 2 ]

			# Grab this for later
			@stream = stream

			# Get the timeout from the config, and if there is one, create a
			# scheduled event to kill us after the timeout expires
			timeout = @timeout || DefaultTimeout
			if timeout > 0 
				@timeoutEvent = 
					MUES::LoginFailureEvent::new( self,
					"Timeout (#{timeout} seconds)." )
				scheduleEvents( Time.now + timeout, @timeoutEvent )
			end

			# Now queue the login banner and the first username prompt output
			# events
			self.queueOutputEvents( MUES::OutputEvent::new(@banner),
									MUES::PromptEvent::new(@userPrompt) )
			
			super
		end


		### Stop the filter in the specified +stream+. Overridden from
		### IOEventFilter.
		def stop( stream )
			cancelScheduledEvents( @timeoutEvent ) if @timeoutEvent

			@stream = nil

			super
		end


		### InputEvent handler: Get username and password information from input
		### events.
		def handleInputEvents( *newEvents )
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
					if @isFinished
						debugMsg 4, "Session is finished. Giving events back to caller."
						returnEvents = events
						break

					# If we've waiting on a pending authevent, queue all events
					elsif @waitingOnEngine
						debugMsg 4, "Session is waiting on engine. Queueing events for later."
						@queuedInput += events
						returnEvents.clear
						break

					# If we've not gotten a username yet, this event's data is the username
					elsif ! @username
						username = untaintString( events.shift.data, UsernameUntaintPattern ).to_s
						debugMsg( 4, "Setting username to '#{username}'." )
						@username = username
						event = HiddenInputPromptEvent::new( @passPrompt )
						self.queueOutputEvents( event )
						next

					# If we've got a username already, and we're not finished or
					# waiting for an auth event to return, then this input event
					# contains the password, so do authentication
					else
						pass = untaintString( events.shift.data, PasswordUntaintPattern ).to_s

						debugMsg 4, "Setting password to '#{pass}', and dispatching " \
							"a LoginSessionAuthEvent."
						authEvent = MUES::LoginAuthEvent::new(
							@stream,
							@username,
							pass,
							self,
							method(:authSuccessCallback),
							method(:authFailureCallback) )

						authEvent.debugLevel = 3
						dispatchEvents( authEvent )

						@waitingOnEngine = true
						@username = nil
					end
				end
			}

			return returnEvents
		end


		### Callback for authentication success. Called by the MUES::Engine
		### after the +user+ successfully authenticates. 
		def authSuccessCallback( user )
			debugMsg( 1, "User authenticated successfully." )

			# Clean up and cancel the pending timeout
			@authMutex.synchronize {
				self.finish
				@waitingOnEngine = false
				cancelScheduledEvents( @timeoutEvent ) if @timeoutEvent
			}

			UserLoginEvent.new( user, stream, self )
		end


		### Callback for authentication failure. Called by the MUES::Engine when
		### the user fails to authenticate for the specified +reason+ (a
		### String).
		def authFailureCallback( reason="None given" )
			debugMsg( 1, "Login failed: #{reason}." )
			@loginAttemptCount += 1

			self.queueOutputEvents( OutputEvent::new("\nAuthentication failure.\n") )

			### After the number of tries specified in the login section of the
			### config, generate a login failure event to kill this session and
			### log the failure
			if @maxTries > 0 && @loginAttemptCount >= @maxTries
				self.log.notice( "Max login tries exceeded for session #{self.id} from #{@remoteHost}." )
				self.queueOutputEvents( OutputEvent::new(">>> Max tries exceeded. <<<") )
				return [ LoginSessionFailureEvent::new(self, "Too many attempts") ]

			### Prompt for username and try again
			else
				self.log.notice( "Failed login attempt #{@loginAttemptCount} from #{@remoteHost}." )
				self.queueOutputEvents( OutputEvent::new("\n" + @userPrompt) )

				@authMutex.synchronize {
					@username = nil
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
				@stream = nil
				@timeoutEvent = nil
			}
		end

		

		#########
		protected
		#########


	end # class LoginSession
end # module MUES

