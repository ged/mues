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

			@params = DefaultParams.merge( params )
			@params[:banner].gsub!( /^[ \t]+/s, '' )
			
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
			if @params[:timeout] > 0 
				@timeoutEvent = 
					MUES::LoginFailureEvent::new( self,
					"Timeout (#{@params[:timeout]} seconds)." )
				scheduleEvents( Time.now + @params[:timeout], @timeoutEvent )
			end

			# Now queue the login banner and the first username prompt output
			# events
			self.queueOutputEvents( MUES::OutputEvent::new(@params[:banner]),
									MUES::PromptEvent::new(@params[:userPrompt]) )
			
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
			returnEvents = nil

			debugMsg( 3, "Handling input events." )
			@authMutex.synchronize {
				events = ( @queuedInput | newEvents )
				@queuedInput.clear

				returnEvents = self.inputHandler( events )
			}

			return returnEvents
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


		### Default input event handler -- override this to handle login
		### sessions that are more complex than just username + password.
		def inputHandler( events )
			returnEvents = []

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

				# If we've not set a username yet, this event's data is the username
				elsif ! @username
					returnEvents << self.setUsername( events.shift )
					next

				# If we've got a username already, and we're not finished or
				# waiting for an auth event to return, then this input event
				# contains the password, so do authentication
				else
					returnEvents << self.setPassword( events.shift )
					next
				end
			end

			return returnEvents.flatten
		end


		### Use the specified input +event+ to set the session's
		### username. Returns true if the username was successfully set, or
		### false if not.
		def setUsername( event )
			@authMutex.synchronize {
				username = untaintString( event.data, UsernameUntaintPattern ).to_s
				debugMsg( 4, "Setting username to '#{username}'." )
				@username = username
				event = HiddenInputPromptEvent::new( @params[:passPrompt] )
				self.queueOutputEvents( event )
			}

			return []
		end


		### Use the specified input +event+ to set the session's password and
		### dispatch a LoginAuthEvent. Returns true if the password was set
		### successfully, false otherwise.
		def setPassword( event )
			@authMutex.synchronize {
				pass = untaintString( event.data, PasswordUntaintPattern ).to_s

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
			}

			return []
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
			if @params[:maxTries] > 0 && @loginAttemptCount >= @params[:maxTries]
				self.log.notice( "Max login tries exceeded for session #{self.id} from #{@remoteHost}." )
				self.queueOutputEvents( OutputEvent::new(">>> Max tries exceeded. <<<") )
				return [ LoginSessionFailureEvent::new(self, "Too many attempts") ]

			### Prompt for username and try again
			else
				self.log.notice( "Failed login attempt #{@loginAttemptCount} from #{@remoteHost}." )
				self.queueOutputEvents( OutputEvent::new("\n" + @params[:userPrompt]) )

				@authMutex.synchronize {
					@username = nil
					@waitingOnEngine = false
				}

				return []
			end

		end



	end # class LoginSession
end # module MUES

