#!/usr/bin/ruby
# 
# This file contains the MUES::Engine class -- the main server class for the
# Multi-User Environment Server (MUES). The server encapsulates and provides a
# simple framework to accomplish the following tasks:
# 
# * Load, configure, and maintain one or more MUES::Environment objects.
# 
# * Handle user connection (MUES::IOEventStream), login (MUES::LoginSession),
#   and user object (MUES::User) maintenance through a client protocol or simple
#   telnet/HTTP connection
# 
# * Maintain one or more MUES::Service objects, which provide shared
#   event-driven services to the hosted game environments
# 
# * Coordinate, queue (MUES::EventQueue), and dispatch events (MUES::Event)
#   between the Environment objects, User objects, and the Services.
# 
# * Execute an event loop which serves as the fundamental unit of time for
#   each environment
# 
# === Subsystems
# 
# The Engine contains four basic kinds of functionality: thread routines, event
# dispatch and handling routines, system startup/shutdown routines, and
# environment interaction functions.
# 
# ==== Threads and Thread Routines
# 
# There are currently two thread routines in the Engine: the routines for the
# main thread of execution and the listener socket. The main thread loops in the
# #_mainThreadRoutine method, marking each loop by dispatching a
# MUES::TickEvent, and then sleeping for a duration of time set in the main
# configuration file. The listener socket also has a thread dedicated to it
# which runs in the #_listenerThreadRoutine method. This thread waits on a call
# to <tt>accept()</tt> for an incoming connection, and dispatches a
# MUES::SocketConnectEvent for each client.
# 
# ==== Event Dispatch and Handling
# 
# The Engine contains the main dispatch mechanism for events in the server in the
# form of a MUES::EventQueue. This class is a prioritized scaling thread
# work crew class which accepts and executes events given to it by the server.
# 
# ==== System Startup and Shutdown
# 
# The Engine is started by means of its start method... <em>(to be continued)</em>.
# 
# === Other Stuff
# 
# You can find more about the MUES project at http://mues.FaerieMUD.org/
# 
# == Synopsis
# 
#   #!/usr/bin/ruby
# 
#   require "mues/Config"
#   require "mues/Engine"
# 
#   $ConfigFile = "MUES.cfg"
# 
#   ### Instantiate the configuration and the server objects
#   config = MUES::Config.new( $ConfigFile )
#   engine = MUES::Engine.instance
# 
#   ### Start up and run the server
#   puts "Starting up...\n"
#   engine.start( config )
#   puts "Shut down...\n"
# 	
# == Rcsid
# 
# $Id: engine.rb,v 1.15 2002/04/01 15:55:54 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Jeremiah Chase <phaedrus@FaerieMUD.org>
# * Alexis Lee <red@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "socket"
require "thread"
require "sync"
require "md5"

require "mues"
require "mues/Log"
require "mues/EventQueue"
require "mues/Exceptions"
require "mues/Events"
require "mues/User"
require "mues/IOEventStream"
require "mues/IOEventFilters"
require "mues/ObjectStore"
require "mues/Environment"
require "mues/LoginSession"
require "mues/Service"

module MUES

	### MUES server class (Singleton)
	class Engine < Object ; implements MUES::Debuggable

		### Container module for Engine State constants. This module contains the
		### following status constants:
		###
		### STOPPED::
		###   halted, not accepting connections, no threads are running.
		### STARTING::
		###   starting up, not accepting connections, main server threads and 
		###   thread queue are starting.
		### RUNNING::
		###   running normally, accepting connections, all threads are running.
		### SHUTDOWN::
		###   halting, not accepting connections, all threads are exiting.
		module State
			STOPPED		= 0
			STARTING	= 1
			RUNNING		= 2
			SHUTDOWN	= 3
		end

		# Import the default event handler dispatch method
		include MUES::Event::Handler

		### Default constants
		Version			= /([\d\.]+)/.match( %q$Revision: 1.15 $ )[1]
		Rcsid			= %q$Id: engine.rb,v 1.15 2002/04/01 15:55:54 deveiant Exp $
		DefaultHost		= 'localhost'
		DefaultPort		= 6565
		DefaultName		= 'ExperimentalMUES'
		DefaultAdmin	= 'MUES Admin <mues@localhost>'

		### Prototype for scheduled events hash (duped before use)
		ScheduledEventsHash = { 'timed' => {}, 'ticked' => {}, 'repeating' => {} }

		### Class variables
		@@Instance		= nil

		### Make the new method private, as this class is a singleton
		private_class_method :new

		### Initialize the Engine instance.
		def initialize # :nodoc:
			@config 				= nil
			@log 					= nil

			@listenerThread			= nil
			@listenerMutex			= Sync.new

			@hostname				= nil
			@port					= nil
			@name					= DefaultName
			@admin					= DefaultAdmin

			@eventQueue				= nil
			@scheduledEvents		= ScheduledEventsHash.dup
			@scheduledEventsMutex	= Sync.new

			@users					= {}
			@usersMutex				= Sync.new
			@environments			= {}
			@environmentsMutex		= Sync.new

			@loginSessions			= []
			@loginSessionsMutex 	= Sync.new

			@exceptionStack			= []
			@exceptionStackMutex	= Sync.new

			@state 					= State::STOPPED
			@startTime 				= nil
			@tick 					= nil

			@engineObjectStore 		= nil

			super()
		end


		######
		public
		######

		# The hostname the server is listening on
		attr_reader :hostname

		# The port the server is listening on
		attr_reader :port

		# The name of the server (used in login prompts, etc.)
		attr_reader :name

		# The system logger (a MUES::Log object)
		attr_reader :log

		# User status table, keyed by MUES::User object
		attr_reader :users

		# Array of connections not yet associated with a user
		# (MUES::LoginSession objects)
		attr_reader :loginSessions

		# Engine state flag (See MUES::Engine::State for values)
		attr_reader :state

		# The current server configuration (a MUES::Config object)
		attr_reader :config


		### Return (after potentially creating) the instance of the Engine,
		### which is a Singleton.
		def Engine.instance

			### :TODO: Put access-checking here to prevent just any old thing from getting the instance

			@@Instance = new() if ! @@Instance
			@@Instance
		end


		### Start the server using the specified configuration object (a
		### MUES::Config object).
		def start( config )
			checkType( config, MUES::Config )

			@state = State::STARTING
			@config = config
			startupEvents = []

			### Change working directory to that specified by the config file
			#Dir.chdir( @config["rootdir"] )
			
			# Set the server name to the one specified by the config
			@name = @config["name"]
			@admin = @config["admin"]
			@tick = 0

			### Sanity-check the log handle and assign it
			@log = Log.new( @config["rootdir"] + "/" + @config["logfile"] )
			@log.notice( "Engine startup for #{@name} at #{Time.now.to_s}" )

			### Connect to the MUES objectstore
			# :TODO: ObjectStore
			@engineObjectStore = ObjectStore.new( @config )
			@engineObjectStore.debugLevel = 0
			@log.info( "Created Engine objectstore: #{@engineObjectStore.to_s}" )

			### Register the server as being interested in a couple of different events
			@log.info( "Registering engine event handlers." )
			registerHandlerForEvents( self, 
									  EngineShutdownEvent,
									  SocketConnectEvent, 
									  UntrappedExceptionEvent, 
									  LogEvent, 
									  UntrappedSignalEvent,
									  UserEvent,
									  LoginSessionEvent,
									  EnvironmentEvent
									 )
			
			### :TODO: Register other event handlers

			### Start the event queue
			@log.info( "Starting event queue." )
			@eventQueue = EventQueue.new( @config["eventqueue"]["minworkers"], 
										  @config["eventqueue"]["maxworkers"],
										  @config["eventqueue"]["threshold"],
										  @config["eventqueue"]["safelevel"] )
			@eventQueue.debugLevel = 0
			@eventQueue.start

			# Load the configured environment classes
			MUES::Environment.loadEnvClasses( @config )

			# Notify all the Notifiables that we're started
			@log.notice( "Sending onEngineStartup() notifications." )
			MUES::Notifiable.classes.each {|klass|
				startupEvents << klass.atEngineStartup( self )
			}

			# Now enqueue any startup events
			startupEvents.flatten!
			startupEvents.compact!
			self.dispatchEvents( *startupEvents ) unless startupEvents.empty?

			### Set up a listener socket on the specified port
			@log.info( "Starting listener thread." )
			@listenerMutex.synchronize( Sync::EX ) {
				@listenerThread = Thread.new { _listenerThreadRoutine }
				@listenerThread.desc = "Listener socket thread"
				@listenerThread.abort_on_exception = true
			}

			# Reset the state to indicate we're running
			@state = State::RUNNING
			@startTime = Time.now

			### Start the event loop
			@log.info( "Starting main thread." )
			_mainThreadRoutine()
			@log.info( "Main thread exited." )

			return true
		end


		### Return +true+ if the server is currently started or running
		def started?
			return @state == State::STARTING || running?
		end


		### Returns +true+ if the server is currently running (ie., started and done
		### with initialization)
		def running?
			return @state == State::RUNNING
		end


		### Shut the server down.
		def stop()
			cleanupEvents = []

			$stderr.puts "In stop()"
			@log.notice( "Stopping engine" )
			@state = State::SHUTDOWN

			### Shut down the listener socket
			@listenerThread.raise( Shutdown )

			### Deactivate all users
			### :TODO: This should be more graceful, perhaps using UserLogoutEvents?
			@usersMutex.synchronize(Sync::EX) {
				@users.each_key do |user|
					cleanupEvents << user.deactivate
				end
			}

			# Notify all the Notifiables that we're shutting down
			@log.notice( "Sending onEngineShutdown() notifications." )
			MUES::Notifiable.classes.each {|klass|
				cleanupEvents << klass.atEngineShutdown( self )
			}

			### Now enqueue any cleanup events as priority events (guaranteed to
			### be executed before the event queue returns from the shutdown()
			### call)
			cleanupEvents.flatten!
			cleanupEvents.compact!
			@log.debug( "Got #{cleanupEvents.length} cleanup events." )
			@eventQueue.priorityEnqueue( *cleanupEvents ) unless cleanupEvents.empty?

			### Shut down the event queue
			@log.notice( "Shutting down and cleaning up event queue" )
			@eventQueue.shutdown

			### :TODO: Needs more thorough cleanup
			return true
		end


		### Returns an Arry of the names of the loaded environments
		def getEnvironmentNames
			return @environments.keys
		end


		### Get the loaded environment with the specified +name+.
		def getEnvironment( name )
			checkType( name, ::String )
			return @environments[name]
		end


		### Load an instance of Environment class specified by
		### <tt>className</tt> and associate it with the specified envName. If
		### <tt>envName</tt> is +nil+, the environment's +name+ method will be
		### called, and its return value used as the associated name.
		def loadEnvironment( className, envName=nil )
			checkType( className, ::String )

			klass = Module::constants.find {|const| const == className}
			unless klass
				fileToRequire = "%s/%s" % [ @config['environmentsDir'], className ]
				require( fileToRequire ) or
					raise EnvironmentLoadError,
					"#{className}: Tried requiring '#{fileToRequire}', to no avail."
				klass = Module::constants.find {|const| const == className} or
					raise EnvironmentLoadError,
					"#{className}: Failed to find class in the list of defined constants ",
					"after requiring '#{fileToRequire}'"
			end

			env = klass.new
			envName ||= env.name
			@environments[envName] = env
		end


		### Queue the given +events+ for dispatch.
		def dispatchEvents( *events )
			checkEachType( events, MUES::Event )
			# @log.debug( "Dispatching #{events.length} events." )
			@eventQueue.enqueue( *events )
		end


		### Schedule the specified <tt>events</tt> to be dispatched at the
		### <tt>time</tt> specified. If <tt>time</tt> is a <tt>Time</tt> object,
		### it will be executed at the tick which occurs immediately after the
		### specified time. If <tt>time</tt> is a positive <tt>Integer</tt>, it is
		### assumed to be a tick offset, and the event will be dispatched
		### <tt>time</tt> ticks from now.  If <tt>time</tt> is a negative
		### <tt>Integer</tt>, it is assumed to be a repeating event which requires
		### dispatch every <tt>time.abs</tt> ticks.
		def scheduleEvents( time, *events )
			checkType( time, ::Time, ::Integer )
			checkEachType( events, MUES::Event )

			# Schedule the events based on what kind of thing 'time' is. In any
			# case, if the time specified has already passed, dispatch the
			# events immediately without scheduling them.
			case time

			# Time-fired events
			when Time
				debugMsg( 3, "Scheduling #{events.length} events for #{time} (Time)" )

				if time <= Time.now()
					dispatchEvents( *events )
				else
					@scheduledEventsMutex.synchronize(Sync::EX) {
						@scheduledEvents['timed'][ time ] ||= []
						@scheduledEvents['timed'][ time ] += events
					}
				end

			# Repeating and tick-fired events
			when Integer

				# A negative time argument means repeating events -- key with an
				# array of two elements: the number of the next tick at which
				# the events should be dispatched, and the interval at which
				# they run
				if time < 0
					tickInterval = time.abs
					nextTick = @tick + tickInterval
					debugMsg( 3, "Scheduling #{events.length} events to repeat every " +
							    "#{tickInterval} ticks (next at #{nextTick})" )
					@scheduledEventsMutex.synchronize(Sync::EX) {
						@scheduledEvents['repeating'][[ nextTick, tickInterval ]] ||= []
						@scheduledEvents['repeating'][[ nextTick, tickInterval ]] += events
					}

				# One-time tick-fired events, keyed by tick number
				elsif time > 0
					time = time.abs
					time += @tick
					debugMsg( 3, "Scheduling #{events.length} events for tick #{time}" )
					@scheduledEventsMutex.synchronize(Sync::EX) {
						@scheduledEvents['ticked'][ time ] ||= []
						@scheduledEvents['ticked'][ time ] += events
					}

				# If the tick is 0, dispatch 'em right away
				else
					dispatchEvents( *events )
				end

			else
				raise ArgumentError, "Schedule time must be a Time or an Integer"
			end

			return true
		end


		### Removes and returns the specified +events+ (MUES::Event objects), if
		### they were scheduled.
		def cancelScheduledEvents( *events )
			checkEachType( events, MUES::Event )
			removedEvents = []

			# If no events were given, remove all scheduled events
			if events.length == 0
				@log.info( "Removing all scheduled events." )
				@scheduledEventsMutex.synchronize(Sync::EX) {
					@scheduledEvents = ScheduledEventsHash.dup
				}

			# Remove just the events specified
			else
				debugMsg( 3, "Cancelling #{events.length} scheduled events." )
				beforeCount = 0
				afterCount = 0

				### Synchronize exclusively to avoid an event that's being
				### cancelled from being executed
				@scheduledEventsMutex.synchronize(Sync::EX) {
					@scheduledEvents.each_key {|type|
						@scheduledEvents[type].each_key {|time|
							beforeCount += @scheduledEvents[type][time].length
							@scheduledEvents[type][time] -= events
							afterCount += @scheduledEvents[type][time].length
						}
					}
				}

				cancelled = beforeCount - afterCount
				debugMsg( 3, "Cancelled #{cancelled} events (#{afterCount} of #{beforeCount} events remain)." )
			end
		end


		### Return a multi-line string indicating the current status of the engine.
		def statusString
			status =	"#{@name}\n"
			status +=	" MUES Engine %s\n" % [ Version ]
			status +=	" Up %.2f seconds at tick %s " % [ Time.now - @startTime, @tick ]
			status +=	" %d users logging in\n" % [ @loginSessions.length ]
			@usersMutex.synchronize(Sync::SH) {
				status +=	" %d users active, %d linkdead\n\n" % 
					[ @users.find_all {|pl,st| st["status"] == "active"}.size,
					  @users.find_all {|pl,st| st["status"] == "linkdead"}.size ]
				status +=	"\n Users:\n"
				@users.keys.each {|user|
					status += "  #{user.to_s}\n"
				}
			}

			status += "\n"
			return status
		end


		### Fetch a connected user object by +name+. Returns +nil+ if no such
		### user is currently connected.
		def getUserByName( name )
			raise SecurityError, "Forbidden method call" if $SAFE >=3
			@users.find {|u| u.username.downcase == name.downcase}
		end



		#########
		protected
		#########

		### Set up and return a listener socket (TCPServer) object on the
		### specified +host+ and +port+. If <tt>tcpWrappered</tt> is
		### <tt>true</tt>, the new socket is wrapped in a TCPWrapper object
		### (using a key of "mues" -- see <tt>hosts_access(5)</tt>) before being
		### returned.
		def _setupListenerSocket( host = DefaultHost, port = DefaultPort, tcpWrappered = false )
			listener = nil
			@host = host
			@port = port

			### Create either just a plain TCPServer or a wrappered one, depending on the config
			if tcpWrappered then
				require "tcpwrap"
				realListener = TCPServer.new( host, port )
				@log.info( "Creating tcp_wrappered listener socket on #{host} port #{port}" )
				listener = TCPWrapper.new( "mues", realListener )
			else
				@log.info( "Creating listener socket on #{host} port #{port}" )
				listener = TCPServer.new( host, port )
			end

			@log.debug( "Returning listener socket." )
			return listener
		end


		### Returns an <tt>Array</tt> of events which are pending execution for the
		### tick specified.
		def _getPendingEvents( currentTick )
			checkType( currentTick, ::Integer )

			pendingEvents = []
			currentTime = Time.now

			# Find and remove pending events, adding them to pendingEvents
			@scheduledEventsMutex.synchronize(Sync::EX) {

				# Time-fired events
				@scheduledEvents['timed'].keys.sort.each {|time|
					break if time > currentTime
					pendingEvents += @scheduledEvents['timed'].delete( time )
				}

				# Tick-fired events
				@scheduledEvents['ticked'].keys.sort.each {|tick|
					break if tick > currentTick
					pendingEvents += @scheduledEvents['ticked'].delete( tick )
				}

				# Repeating events -- sort works with the interval arrays, too,
				# so that the event groups that are due first will sort
				# first. We delete the old scheduled group, update the interval
				# values, and merge with any already-extant group at the new
				# interval.
				@scheduledEvents['repeating'].keys.sort.each {|interval|
					break if interval[0] > currentTick
					newInterval = [ interval[0]+interval[1], interval[1] ]
					events = @scheduledEvents['repeating'].delete( interval )
					@scheduledEvents['repeating'][newInterval] ||= []
					@scheduledEvents['repeating'][newInterval] += events
					pendingEvents += events
				}
			}

			return pendingEvents.flatten
		end


		#############################################################
		###	T H R E A D   R O U T I N E S
		#############################################################

		### The main event loop. This is the routine that the main thread runs,
		### dispatching pending scheduled events and TickEvents for timing. Exits
		### and returns the total number of ticks to the caller after #stop is
		### called.
		def _mainThreadRoutine

			Thread.current.desc = "[Main]"

			### Start the event loop until the engine stops running
			@log.notice( "Starting event loop." )
			while running? do
				begin
					@tick += 1
					# @log.debug( "In tick #{@tick}..." )
					sleep @config["engine"]["TickLength"].to_i
					pendingEvents = _getPendingEvents( @tick )
					dispatchEvents( TickEvent.new(@tick), *pendingEvents )
				rescue StandardError => e
					dispatchEvents( UntrappedExceptionEvent.new(e) )
					next
				rescue Interrupt, SignalException => e
					dispatchEvents( UntrappedSignalEvent.new(e) )
				end
			end
			@log.notice( "Exiting event loop." )

			return @tick
		end


		### Routine for the thread that sets up and maintains the listener
		### socket.
		def _listenerThreadRoutine
			@log.debug( "In _listenerThreadRoutine" )
			sleep 1 until running?
			listener = _setupListenerSocket( @config["engine"]["bindaddress"], 
											 @config["engine"]["bindport"],
											 @config["engine"]["tcpwrapper"] )
			@log.notice( "Accepting connections on #{listener.addr[2]} port #{listener.addr[1]}." )

			### :TODO: Fix race condition: If a connection comes in after stop()
			### has been called, but before the Shutdown exception has been
			### dispatched.
			while running? do
				begin
					userSock = listener.accept
					@log.info( "Connect from #{userSock.addr[2]}" )
					dispatchEvents( SocketConnectEvent.new(userSock) )
				rescue Errno::EPROTO
					dispatchEvents( LogEvent.new("error", "Listener thread: Accept failed (EPROTO).") )
					next
				rescue Reload
					dispatchEvents( LogEvent.new("notice", "Listener thread: Got notice of configuration reload.") )
					break
				rescue Shutdown
					@log.notice( "Listener thread: Got notice of server shutdown." )
					break
				rescue
					dispatchEvents( UntrappedExceptionEvent.new($!) )
					next
				end
			end

			@host = @port = nil

			listener.shutdown( 2 )
			listener.close

			@log.notice( "Listener thread exiting." )
		end


		#############################################################
		###	E V E N T   H A N D L E R S
		#############################################################

		### Handle connections to the listener socket.
		def _handleSocketConnectEvent( event )
			results = []
			results.push LogEvent.new("Socket connect event from '#{event.socket.addr[2]}'.")

			### :TODO: Handle bans here

			### Copy the event's socket to dynamic variable, and create a socket
			### output filter
			sock = event.socket
			soFilter = TelnetOutputFilter.new( sock )
			#soFilter = SocketOutputFilter.new( sock )
			soFilter.debugLevel = 2

			### Create the event stream, add the new filters to the stream
			ios = IOEventStream.new
			ios.debugLevel = 0
			ios.addFilters( soFilter )

			### Create the login session and add it to our collection
			session = LoginSession.new( @config, ios, sock.addr[2] )
			session.debugLevel = 0
			@loginSessionsMutex.synchronize(Sync::EX) {
				@loginSessions.push session
			}

			return results
		end


		### Handle MUES::UserLoginEvent +event+.
		def _handleUserLoginEvent( event )
			user = event.user

			results = []
			@log.debug( "In _handleUserEvent. Event is: #{event.to_s}" )

			stream = event.stream
			loginSession = event.loginSession

			# Set last login time and host in the user record
			user.lastLogin = Time.now
			user.remoteHost = loginSession.remoteHost

			### If the user object is already active (ie., already connected
			### and has a shell), remove the old socket connection and
			### re-connect with the new one. Otherwise just activate the
			### user object.
			if user.activated?
				results << LogEvent.new( "notice", "User #{user.to_s} reconnected." )
				results << user.reconnect( stream )
			else
				results << LogEvent.new( "notice", "Login succeeded for #{user.to_s}." )
				results << user.activate( stream, @config['motd'] )
			end
			
			# Add the activated user to our userlist, and remove the spent
			# login session from our list of active logins
			@usersMutex.synchronize(Sync::EX) {
				@users[ user ] = { "status" => "active" }
			}
			@loginSessionsMutex.synchronize( Sync::EX ) {
				@loginSessions -= [ loginSession ]
			}
			
			return results
		end


		### Handle MUES::UserDisconnectEvent +event+ by marking the user's
		### object as "linkdead" and deactivating her IOEventStream.
		def _handleUserDisconnectEvent( event )
			user = event.user

			results = []
			@log.debug( "In _handleUserDisconnectEvent. Event is: #{event.to_s}" )

			results << LogEvent.new("notice", "User #{user.name} went link-dead.")
			@usersMutex.synchronize(Sync::EX) { @users[ user ]["status"] = "linkdead" }
			results << user.deactivate

			return results
		end


		### Handle MUES::UserIdleTimeoutEvent +event+ by disconnecting him.
		def _handleUserIdleTimeoutEvent( event )
			user = event.user

			results = []
			@log.debug( "In _handleUserIdleTimeoutEvent. Event is: #{event.to_s}" )

			results << LogEvent.new("notice", "User #{user.name} disconnected due to idle timeout.")
			# @usersMutex.synchronize {	@users[ user ]["status"] = "linkdead" }
			@usersMutex.synchronize(Sync::EX) { @users.delete( user ) }
			user.deactivate

			return results
		end


		### Handle MUES::UserLogoutEvent +event+. Remove the user object from
		### the user table and deactivate it.
		def _handleUserLogoutEvent( event )
			user = event.user

			results = []
			@log.debug( "In _handleUserLogoutEvent. Event is: #{event.to_s}" )

			results << LogEvent.new("notice", "User #{user.to_s} disconnected.")
			@usersMutex.synchronize(Sync::EX) { @users.delete( user ) }
			user.deactivate

			return results
		end


		### Handle MUES::UserSaveEvent +event+ by updating the stored version of
		### the corresponding user object.
		def _handleUserSaveEvent( event )
			user = event.user

			results = []
			@log.debug( "In UserSaveEvent handler for #{user.to_s}" )
			results << LogEvent.new("info", "Saving record for user #{user.to_s}.")
			inCritical = Thread.critical

			begin
				Thread.critical = true

				### :TODO: ObjectStore
				@engineObjectStore.storeUser( user )
				results << LogEvent.new("info", "Saved user record for #{user.to_s}")
			rescue Exception => e
				@log.error( "Error while saving #{user.to_s}: ", e.backtrace.join("\n") )
				results << LogEvent.new("error", "Exception while storing user record for #{user.to_s}")
				### :TODO: Perhaps dump to a rescue file or something?
			ensure
				Thread.critical = inCritical
			end

			return results
		end


		### Handle a user authentication attempt event.
		def _handleLoginSessionAuthEvent( event )
			session = event.session
			remoteHost = event.remoteHost
			username = event.username
			password = event.password
			user = nil

			results = []
			results << LogEvent.new( "info", "Authentication event from session %s for %s@%s" % [
											session.id,
											username,
											remoteHost ])

			### :TODO: Check user bans
			### Look for a user with the same name as the one logging in...
			@usersMutex.synchronize(Sync::SH) {
				user = @users.keys.find {|p| p.username == username }
			}
			### :TODO: ObjectStore
			user ||= @engineObjectStore.fetchUser( username )

			debugMsg( 2, "Fetched user #{user.inspect} for '#{username}'" )

			### Fail if no user was found by the name specified...
			if user.nil?
				results << LogEvent.new( "notice", "Authentication failed for user '#{username}': No such user." )
				results << event.failureCallback.call( "No such user" )

			### ...or if the passwords don't match
			elsif user.cryptedPass != MD5.new( event.password ).hexdigest
				debugMsg( 1, "Bad password '%s': '%s' != '%s'" % [
							 event.password,
							 user.cryptedPass,
							 MD5.new( event.password ).hexdigest] )
				results << LogEvent.new( "notice", "Authentication failed for user '#{username}': Bad password." )
				results << event.failureCallback.call( "Bad password" )

			### Otherwise succeed
			else
				results << LogEvent.new( "notice", "User '#{username}' authenticated successfully." )
				results << event.successCallback.call( user )
			end

			return results.flatten
		end


		### Handle a user authentication failure event.
		def _handleLoginSessionFailureEvent( event )
			session = event.session
			logEvent = LogEvent.new("notice", "Login session #{session.id} failed. Terminating.")

			session.terminate
			@loginSessionsMutex.synchronize(Sync::EX) {
				@loginSessions -= [ session ]
			}

			return [ logEvent ]
		end


		### Handle environment events.
		def _handleEnvironmentEvent( event )
			checkType( event, MUES::EnvironmentEvent )

			results = []

			# Handle various kinds of environment events
			case event

			# Load a new environment
			when LoadEnvironmentEvent
				begin
					@environmentsMutex.synchronize( Sync::SH ) {

						# Make sure the environment specified isn't already loaded
						if @environments.has_key?( event.name )
							raise EnvironmentLoadError, "Cannot load environment '#{event.name}': Already loaded."

						else

							# Load the environment object, reporting any errors
							environment = MUES::Environment.create( event.spec )

							@environmentsMutex.synchronize( Sync::EX ) {
								@environments[event.name] = environment
								results << @environments[event.name].start()
							}
						end
					}

					# Report success
					unless event.user.nil?
						event.user.handleEvent(OutputEvent.new( "Successfully loaded '#{event.name}'\n\n" ))
					end

				rescue EnvironmentLoadError => e
					@log.error( "%s: %s" % [e.message, e.backtrace.join("\t\n")] )

					# If the event is associated with a user, send them a diagnostic event
					unless event.user.nil?
						event.user.handleEvent(OutputEvent.new( e.message + "\n\n" ))
					end
				end

			# Unload a loaded environment
			when UnloadEnvironmentEvent
				begin
					@environmentsMutex.synchronize( Sync::SH ) {

						# Make sure the environment specified exists
						unless @environments.has_key?( event.name )
							raise EnvironmentUnloadError, "Cannot unload environment '#{event.name}': Not loaded."

						else

							# Unload the environment object, reporting any errors
							@environmentsMutex.synchronize( Sync::EX ) {
								results << @environments[event.name].shutdown()
								@environments[event.name] = nil
							}
						end
					}

					# Report success
					unless event.user.nil?
						event.user.handleEvent(OutputEvent.new( "Successfully unloaded '#{event.name}'" ))
					end

				rescue EnvironmentUnloadError => e
					@log.error( "%s: %s" % [e.message, e.backtrace.join("\t\n")] )

					# If the event is associated with a user, send them a diagnostic event
					unless event.user.nil?
						event.user.handleEvent(OutputEvent.new( e.message + "\n\n" ))
					end
				end
				

			# We don't handle any other kinds of environment events, so handle
			# them with the default handler
			else
				results << _handleEvent( event )
			end

			return results
		end


		### Handle untrapped exceptions.
		def _handleUntrappedExceptionEvent( event )
			maxSize = @config["engine"]["exceptionStackSize"].to_i
			
			@exceptionStackMutex.synchronize(Sync::EX) {
				@exceptionStack.push event.exception
				while @exceptionStack.length > maxSize
					@exceptionStack.delete_at( maxSize )
				end
			}

			@log.error( "Untrapped exception: #{event.exception.to_s}" )
			
			return [ LogEvent.new( "error", "Untrapped exception: ",
								   event.exception.to_s, "\n\t", 
								   event.exception.backtrace.join("\n\t") ) ]
		end


		### Handle untrapped signals.
		def _handleUntrappedSignalEvent( event )
			if event.exception.is_a?( Interrupt ) then
				@log.crit( "Caught interrupt. Shutting down." )
				stop()
			else
				_handleUntrappedExceptionEvent( event )
			end
		end


		### Handle any reconfiguration events by re-reading the config
		### file and then reconnecting the listen socket.
		def _handleReconfigEvent( event )
			results = []

			begin
				Thread.critical = true
				@config.reload
			rescue StandardError => e
				results.push LogEvent.new("error", "Exception encountered while reloading: #{e.to_s}")
			ensure
				Thread.critical = false
			end

			@listenerMutex.synchronize( Sync::EX ) {
				oldListenerThread = @listenerThread
				oldListenerThread.raise Reload
				oldListenerThread.join

				@listenerThread = Thread.new { _listenerThreadRoutine }
				@listenerThread.abort_on_exception = true
			}

			return []
		end


		### Handle any system events that don't have explicit handlers.
		def _handleSystemEvent( event )
			results = []

			case event
			when EngineShutdownEvent
				@log.notice( "Engine shut down by #{event.agent.to_s}." )
				stop()

			when GarbageCollectionEvent
				@log.notice( "Starting forced garbage collection." )
				GC.start

			else
				results.push LogEvent.new("notice", 
										  "Got a system event (a #{event.class.name}) " +
										  "that is not yet handled.")
			end

			return results
		end

		### Handle logging events by writing their content to the syslog.
		def _handleLogEvent( event )
			@log.send( event.severity, event.message )
			return []
		end


		### Handle events for which we don't have an explicit handler.
		def _handleUnknownEvent( event )
			@log.error( "Engine received unhandled event type '#{event.class.name}'." )
			return []
		end

	end # class Engine
end # module MUES


