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
# #mainThreadRoutine method, marking each loop by dispatching a
# MUES::TickEvent, and then sleeping for a duration of time set in the main
# configuration file. The listener socket also has a thread dedicated to it
# which runs in the #listenerThreadRoutine method. This thread waits on a call
# to <tt>accept()</tt> for an incoming connection, and dispatches a
# MUES::ListenerConnectEvent for each client.
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
# $Id: engine.rb,v 1.16 2002/08/01 01:01:58 deveiant Exp $
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
require "poll"

require "mues"
require "mues/Log"
require "mues/Config"
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
require "mues/Listener"
require "mues/PollProxy"


module MUES

	### MUES server class (Singleton)
	class Engine < Object ; implements MUES::Debuggable

		include MUES::TypeCheckFunctions, MUES::SafeCheckFunctions

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
		Version				= /([\d\.]+)/.match( %q$Revision: 1.16 $ )[1]
		Rcsid				= %q$Id: engine.rb,v 1.16 2002/08/01 01:01:58 deveiant Exp $
		DefaultHost			= 'localhost'
		DefaultPort			= 6565
		DefaultName			= 'ExperimentalMUES'
		DefaultAdmin		= 'MUES Admin <mues@localhost>'
		DefaultPollInterval	= 0.25

		### Prototype for scheduled events hash (duped before use)
		ScheduledEventsHash = { 'timed' => {}, 'ticked' => {}, 'repeating' => {} }

		### Class variables
		@@Instance		= nil

		### Callback passed to the poll object for listeners (defined the first
		### time #registerListener is called).
		@@ListenerConnectCallback = nil


		### Make the new method private, as this class is a singleton
		private_class_method :new

		### Initialize the Engine instance.
		def initialize # :nodoc:
			@config 				= nil							# Configuration object
			@log 					= self.log						# MUES::Log (Log4r) Logger

			@listenerThread			= nil							# Thread for the listeners
			@pollObj				= Poll::new

			@hostname				= nil
			@port					= nil
			@name					= DefaultName
			@admin					= DefaultAdmin

			@eventQueue				= nil
			@scheduledEvents		= ScheduledEventsHash.dup
			@scheduledEventsMutex	= Sync::new

			@users					= {}
			@usersMutex				= Sync::new

			@environments			= {}
			@environmentsMutex		= Sync::new

			@listeners				= {}
			@listenersMutex			= Sync::new

			@loginSessions			= []
			@loginSessionsMutex 	= Sync::new

			@exceptionStack			= []
			@exceptionStackMutex	= Sync::new

			@state 					= State::STOPPED

			@startTime 				= nil
			@tick 					= nil

			@commandShellFactory	= nil

			@userObjectStore 		= nil
			@banObjectStore			= nil
			@envObjectStore			= nil

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

		# User status table, keyed by MUES::User object
		attr_reader :users

		# Array of connections not yet associated with a user
		# (MUES::LoginSession objects)
		attr_reader :loginSessions

		# Engine state flag (See MUES::Engine::State for values)
		attr_reader :state

		# The current server configuration (a MUES::Config object)
		attr_reader :config

		# The MUES::CommandShell::CommandShellFactory object -- used for
		# creating command shell objects for connecting users.
		attr_reader :commandShellFactory
		

		### Return (after potentially creating) the instance of the Engine,
		### which is a Singleton.
		def Engine.instance
			MUES::SafeCheckFunctions::checkSafe( 2 )

			@@Instance = new() if ! @@Instance
			@@Instance
		end


		### Start the server using the specified configuration object (a
		### MUES::Config object).
		def start( config )
			checkType( config, MUES::Config )

			ignoreSignals()

			@state = State::STARTING
			@config = config
			startupEvents = []

			# Set up the Engine
			startupEvents += setupEngine( config )

			# Now start up any other configured systems
			startupEvents += setupEnvironments( config )
			startupEvents += sendEngineStartupNotifications()
			startupEvents += setupListeners( config )
			
			# Now enqueue any startup events
			self.dispatchEvents( *(startupEvents.flatten.compact) ) unless startupEvents.empty?

			# Reset the state to indicate we're running
			@state = State::RUNNING
			@startTime = Time.now

			### Start the event loop
			@log.info( "Starting main thread." )
			mainThreadRoutine()
			@log.info( "Main thread exited." )

			return true
		end


		### Configure the engine with the <tt>engine</tt> section of the
		### specified configuration (a MUES::Config object).
		def setupEngine( config )

			setupEvents = []

			### Set up subsystems
			setupEvents += setupLogging( config )
			setupEvents += setupObjectStore( config )
			setupEvents += setupEventHandlers( config )
			setupEvents += setupEventQueue( config )
			setupEvents += setupCommandShellFactory( config )

			### Change working directory to that specified by the config file
			Dir.chdir( @config.engine.root_dir )
			
			# Set the server name to the one specified by the config
			@name = @config.general.server_name
			@admin = @config.general.server_admin
			@tick = 0

			return []
		end

		
		### Configure the logging subsystem (Log4r) according to the
		### <tt>logging</tt> section of the specified config (a MUES::Config
		### object).
		def setupLogging( config )
			MUES::Log::configure( config )
		end


		### Set up the Engine's MUES::ObjectStore according to the specified
		### config (a MUES::Config object).
		def setupObjectStore( config )
			@engineObjectStore = MUES::ObjectStore::createFromConfig( @config.engine.objectstore )
			@log.info( "Created Engine objectstore: #{@engineObjectStore.to_s}" )
		end


		### Set up the Engine's event handlers
		def setupEventHandlers( config )
			# Register the server's handled event classes
			# :TODO: Register other event handlers
			@log.info( "Registering engine event handlers." )
			registerHandlerForEvents( self, 
									  EngineShutdownEvent,
									  ListenerConnectEvent, 
									  UntrappedExceptionEvent, 
									  LogEvent, 
									  UntrappedSignalEvent,
									  UserEvent,
									  LoginSessionEvent,
									  EnvironmentEvent
									 )
		end


		### Set up the Engine's event queue according to the specified config (a
		### MUES::Config object).
		def setupEventQueue( config )

			### Start the event queue
			@log.info( "Starting event queue." )
			@eventQueue = EventQueue::createFromConfig( config )
			@eventQueue.debugLevel = 0
			@eventQueue.start
		end


		### Set up the MUES::CommandShell::Factory used to create new user
		### command shells. It creates instances of the class specified in the
		### specified config (a MUES::Config object), which defaults to
		### MUES::CommandShell.
		def setupCommandShellFactory( config )
			
			### Create the factory
			@log.info( "Creating command shell factory." )
			@commandShellFactory = MUES::CommandShell::Factory::new( config )

			return []
		end


		### Set up the preloaded environments specified in the given config (a
		### MUES::Config object).
		def setupEnvironments( config )

			# Load the configured environment classes
			MUES::Environment.createFromConfig( config ).each {|env|
				@environmentsMutex.synchronize( Sync::EX ) {
					@environments[ env.name ] = env
				}
			}

			return []
		end


		### Set up the listener objects specified by the given config (a
		### MUES::Config object) in a dedicated thread.
		def setupListeners( config )
			@listenersMutex.synchronize( Sync::EX ) {

				# Load the listeners from the configuration, installing each one
				# in the listeners hash
				MUES::Listener.createFromConfig( config ).each {|listener|
					self.addListener( listener )
				}

				@log.notice( "Starting listener thread." )

				# Start the polling thread for the listeners
				@listenerThread = Thread.new {
					listenerThreadRoutine()
				}

				@listenerThread.desc = "Listener polling thread"
				@listenerThread.abort_on_exception = true
			}

			return []
		end


		### Set up signal handlers to generate events.
		def setupSignalHandlers( config )
			self.log.info( "Installing signal handlers." )

			trap( "INT" ) { self.dispatchEvents(SignalEvent::new( :INT, "Server caught SIGINT" )) }
			trap( "TERM" ) { self.dispatchEvents(SignalEvent::new( :TERM, "Server caught SIGTERM" )) }
			trap( "HUP" ) { self.dispatchEvent(SignalEvent::new( :HUP, ">>> Server reset <<<" )) }

			return []
		end


		### Set signal handlers to ignore signals while the server is in startup
		### or shutdown
		def ignoreSignals
			self.log.info( "Ignoring signals." )

			trap( "INT", "SIG_IGN" )
			trap( "TERM", "SIG_IGN" )
			trap( "HUP", "SIG_IGN" )
		end


		### Send notifications about the engine starting up to the classes which
		### have registered themselves as interested in receiving such
		### notification (by implementing MUES::Notifiable).
		def sendEngineStartupNotifications
			# Notify all the Notifiables that we're started
			@log.notice( "Sending onEngineStartup() notifications." )
			MUES::Notifiable.classes.each {|klass|
				startupEvents << klass.atEngineStartup( self )
			}
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

			@log.notice( "Stopping engine" )
			@state = State::SHUTDOWN

			### Shut down the listeners thread
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
				cleanupEvents += klass.atEngineShutdown( self )
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


		### Create an environment specified by the given <tt>className</tt> and
		### install it in the list of running environments with the specified
		### <tt>instanceName</tt>. Returns any setup events that the environment
		### propagated when it was started, which should be propagated by the
		### caller.
		def loadEnvironment( className, instanceName )
			results = []

			@environmentsMutex.synchronize( Sync::SH ) {

				# Make sure the environment specified isn't already loaded
				if @environments.has_key?( instanceName )
					raise EnvironmentLoadError,
						"Cannot load environment '#{instanceName}': Already loaded."

				else

					# Create the environment object
					environment = MUES::Environment::create( className, instanceName )

					@environmentsMutex.synchronize( Sync::EX ) {
						@environments[instanceName] = environment
						results << @environments[instanceName].start()
					}
				end
			}

			return results
		end


		### Unload the running environment specified by <tt>instanceName</tt>.
		### Returns any cleanup events that were propagated by the environment
		### when it shut down, which should be propagated by the caller.
		def unloadEnvironment( instanceName )
			results = []

			@environmentsMutex.synchronize( Sync::SH ) {

				# Make sure the environment specified exists
				unless @environments.has_key?( instanceName )
					raise EnvironmentUnloadError,
						"Cannot unload environment '#{instanceName}': Not loaded."

				else

					# Unload the environment object, reporting any errors
					@environmentsMutex.synchronize( Sync::EX ) {
						results << @environments[instanceName].shutdown()
						@environments[instanceName] = nil
					}
				end
			}
			return results
		end


		### Add the specified listeners to the engine's hash of listeners and
		### register them with the poll object.
		def addListeners( *listeners )
			checkEachType( listeners, MUES::Listener )

			@listenersMutex.synchronize( Sync::SH ) {
				listeners.each {|listener|
					@listenersMutex.synchronize( Sync::EX ) {
						@listeners[ listener.name ] = listener
						registerListener( listener )
					}
				}
			}
		end

		### Remove the specified listeners (which may be either MUES::Listener
		### objects, or the names they're registered as) from the Engine's hash
		### of listeners, and unregister them from the poll object.
		def removeListeners( *listeners )
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
			status +=	" Up %.2f seconds at tick %s " % [ Time.now - @startTime, @tick ] #. <- Wanky font-lock
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
			checkSafeLevel( 3 )
			@users.find {|u| u.username.downcase == name.downcase}
		end


		### Fetch a listener object by +name+. Returns +nil+ if no such listener
		### is currently installed.
		def getListenerByName( name )
			checkSafeLevel( 3 )
			@listeners.find {|u| u.listener.name.downcase == name.downcase}
		end


		### Fetch a running environment by +name+. Returns +nil+ if no such
		### environment is currently running.
		def getEnvironmentByName( name )
			checkSafeLevel( 3 )
			@environments.find {|u| u.environmentname.downcase == name.downcase}
		end



		#########
		protected
		#########

		### Returns an <tt>Array</tt> of events which are pending execution for the
		### tick specified.
		def getPendingEvents( currentTick )
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


		### Register the specified listener with the Engine's Poll object.
		def registerListener( listener )
			checkType( listener, MUES::Listener )

			# Define the callback Proc used for all Listeners if it hasn't been already
			@@ListenerConnectCallback ||= Proc::new {|sock,mask,listener|
				case mask

				# Normal readable event
				when Poll::RDNORM
					self.dispatchEvents( ListenerConnectEvent::new(listener, poll) )

				# Error events
				when Poll::ERR|Poll::HUP|Poll::NVAL
					self.dispatchEvents( ListenerErrorEvent::new(listener, poll, mask) )
					poll.unregister( listener.ioObject )

				# Everything else
				else
					self.log.error( "Unhandled Listener poll event #{mask.inspect}" )
				end
			}

			# Now register the listener with the poll object
			@listenersMutex.synchronize( Sync::EX ) {
				@pollObj.register( listener.ioObject, Poll::RDNORM, @@ListenerConnectCallback, listener )
			}

			return poll
		end


		### Un-register the specified listener with the Engine's Poll object
		def unregisterListener( listener )
			checkType( listener, MUES::Listener )

			@listenersMutex.synchronize( Sync::EX ) {
				@pollObj.unregister( listener.ioObject )
			}
		end



		#############################################################
		###	T H R E A D   R O U T I N E S
		#############################################################

		### The main event loop. This is the routine that the main thread runs,
		### dispatching pending scheduled events and TickEvents for timing. Exits
		### and returns the total number of ticks to the caller after #stop is
		### called.
		def mainThreadRoutine

			Thread.current.desc = "[Main]"

			### Start the event loop until the engine stops running
			@log.notice( "Starting event loop." )
			while running? do
				setupSignalHandlers()

				begin
					@tick += 1
					debugMsg( 5, "In tick #{@tick}..." )
					sleep @config.engine.tick_length.to_i
					pendingEvents = getPendingEvents( @tick )
					dispatchEvents( TickEvent.new(@tick), *pendingEvents )
				rescue StandardError => e
					dispatchEvents( UntrappedExceptionEvent.new(e) )
					next
				rescue Interrupt, SignalException => e
					dispatchEvents( UntrappedSignalEvent.new(e) )
				end
			end
			@log.notice( "Exiting event loop." )
			ignoreSignals()

			return @tick
		end


		### Routine for the thread that sets up and maintains the listener
		### socket.
		def listenerThreadRoutine
			@log.info( "Starting listener thread routine" )
			sleep 1 until running?

			begin

				interval = @config.poll_interval.to_f || DefaultPollInterval
				getRegisteredPollObject( *@listeners.values )

				### :TODO: Fix race condition: If a connection comes in after stop()
				### has been called, but before the Shutdown exception has been
				### dispatched.
				while running? do
					begin
						pollObj.poll( @pollInterval )
					rescue
						dispatchEvents( UntrappedExceptionEvent.new($!) )
						next
					end
				end

			rescue Reload
				@log.notice( "Listener thread: Got notice of configuration reload." )
				break
			rescue Shutdown
				@log.notice( "Listener thread: Got notice of server shutdown." )
				break
			end

			listener.shutdown( 2 )
			listener.close

			@log.notice( "Listener thread exiting." )
		end



		#############################################################
		###	E V E N T   H A N D L E R S
		#############################################################

		### Handle connections to listeners.
		def handleListenerConnectEvent( event )
			@log.notice( "Connect event for #{event.listener.to_s}." )

			listener = event.listener

			soFilter = listener.createOutputFilter( @pollObj )
			soFilter.debugLevel = 2

			### :TODO: Handle bans here

			### Create the event stream, add the new filters to the stream
			ios = IOEventStream::new
			ios.debugLevel = 0
			ios.addFilters( soFilter )

			### Create the login session and add it to our collection
			session = LoginSession::new( @config, ios, sock.addr[2] )
			session.debugLevel = 0
			@loginSessionsMutex.synchronize(Sync::EX) {
				@loginSessions.push session
			}

			return []
		end


		### Handle disconnections on filters created by listeners.
		def handleListenerDisconnectEvent( event )
			# Not sure how this event will get here yet...

			# listener.releaseOutputFilter( @event.filter )
		end


		### Handle MUES::UserLoginEvent +event+.
		def handleUserLoginEvent( event )
			user = event.user

			results = []
			@log.debug( "In handleUserEvent. Event is: #{event.to_s}" )

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
				self.log.notice( "User #{user.to_s} reconnected." )
				results << user.reconnect( stream )
			else
				self.log.notice( "Login succeeded for #{user.to_s}." )
				cshell = @commandShellFactory.createShellForUser( user )
				results << user.activate( stream, cshell, config.general.motd )
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
		def handleUserDisconnectEvent( event )
			user = event.user

			results = []
			@log.debug( "In handleUserDisconnectEvent. Event is: #{event.to_s}" )

			self.log.notice("User #{user.name} went link-dead.")
			@usersMutex.synchronize(Sync::EX) { @users[ user ]["status"] = "linkdead" }
			results << user.deactivate

			return results
		end


		### Handle MUES::UserIdleTimeoutEvent +event+ by disconnecting him.
		def handleUserIdleTimeoutEvent( event )
			user = event.user

			results = []
			@log.debug( "In handleUserIdleTimeoutEvent. Event is: #{event.to_s}" )

			self.log.notice("User #{user.name} disconnected due to idle timeout.")
			# @usersMutex.synchronize {	@users[ user ]["status"] = "linkdead" }
			@usersMutex.synchronize(Sync::EX) { @users.delete( user ) }
			user.deactivate

			return results
		end


		### Handle MUES::UserLogoutEvent +event+. Remove the user object from
		### the user table and deactivate it.
		def handleUserLogoutEvent( event )
			user = event.user

			results = []
			@log.debug( "In handleUserLogoutEvent. Event is: #{event.to_s}" )

			self.log.notice("User #{user.to_s} disconnected.")
			@usersMutex.synchronize(Sync::EX) { @users.delete( user ) }
			user.deactivate

			return results
		end


		### Handle MUES::UserSaveEvent +event+ by updating the stored version of
		### the corresponding user object.
		def handleUserSaveEvent( event )
			user = event.user

			results = []
			@log.debug( "In UserSaveEvent handler for #{user.to_s}" )
			self.log.info("Saving record for user #{user.to_s}.")
			inCritical = Thread.critical

			begin
				Thread.critical = true

				### :TODO: ObjectStore
				@engineObjectStore.storeUser( user )
				self.log.info("Saved user record for #{user.to_s}")
			rescue Exception => e
				@log.error( "Error while saving #{user.to_s}: ", e.backtrace.join("\n") )
				self.log.error("Exception while storing user record for #{user.to_s}")
				### :TODO: Perhaps dump to a rescue file or something?
			ensure
				Thread.critical = inCritical
			end

			return results
		end


		### Handle a user authentication attempt event.
		def handleLoginSessionAuthEvent( event )
			session = event.session
			remoteHost = event.remoteHost
			username = event.username
			password = event.password
			user = nil

			@log.info( "Authentication event from session %s for %s@%s" %
					   [ session.id, username, remoteHost ] )
			results = []

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
				@log.notice( "Authentication failed for user '#{username}': No such user." )
				results << event.failureCallback.call( "No such user" )

			### ...or if the passwords don't match
			elsif user.cryptedPass != MD5.new( event.password ).hexdigest
				debugMsg( 1, "Bad password '%s': '%s' != '%s'" % [
							 event.password,
							 user.cryptedPass,
							 MD5.new( event.password ).hexdigest] )
				@log.notice( "Authentication failed for user '#{username}': Bad password." )
				results << event.failureCallback.call( "Bad password" )

			### Otherwise succeed
			else
				@log.notice( "User '#{username}' authenticated successfully." )
				results << event.successCallback.call( user )
			end

			return results.flatten
		end


		### Handle a user authentication failure event.
		def handleLoginSessionFailureEvent( event )
			session = event.session
			logEvent = @log.notice( "Login session #{session.id} failed. Terminating." )

			session.terminate
			@loginSessionsMutex.synchronize(Sync::EX) {
				@loginSessions -= [ session ]
			}

			return [ logEvent ]
		end


		### Handle LoadEnvironmentEvents by loading the specified environment.
		def handleLoadEnvironmentEvent( event )
			checkType( event, MUES::EnvironmentEvent )

			results = self.loadEnvironment( event.spec, event.name )

			# Report success
			unless event.user.nil?
				event.user.handleEvent(OutputEvent.new( "Successfully loaded '#{event.name}'\n\n" ))
			end

			return results
		rescue EnvironmentLoadError => e
			@log.error( "%s: %s" % [e.message, e.backtrace.join("\t\n")] )

			# If the event is associated with a user, send them a diagnostic event
			unless event.user.nil?
				event.user.handleEvent(OutputEvent.new( e.message + "\n\n" ))
			end

			return []
		end


		### Handle UnloadEnvironmentEvents by unloading the specified
		### environment.
		def handleUnloadEnvironmentEvent( event )
			checkType( event, MUES::EnvironmentEvent )

			results = self.unloadEnvironment( event.name )

			# Report success
			unless event.user.nil?
				event.user.handleEvent(OutputEvent.new( "Successfully unloaded '#{event.name}'" ))
			end

			return results
		rescue EnvironmentUnloadError => e
			@log.error( "%s: %s" % [e.message, e.backtrace.join("\t\n")] )

			# If the event is associated with a user, send them a diagnostic event
			unless event.user.nil?
				event.user.handleEvent(OutputEvent.new( e.message + "\n\n" ))
			end

			return []
		end
				

		### Handle untrapped exceptions.
		def handleUntrappedExceptionEvent( event )
			maxSize = @config.engine.exception_stack_size.to_i
			
			@exceptionStackMutex.synchronize(Sync::EX) {
				@exceptionStack.push event.exception
				while @exceptionStack.length > maxSize
					@exceptionStack.delete_at( maxSize )
				end
			}

			@log.error( "Untrapped exception: #{event.exception.to_s}" )
			return []
		end


		### Handle untrapped signals.
		def handleUntrappedSignalEvent( event )
			if event.exception.is_a?( Interrupt ) then
				@log.crit( "Caught interrupt. Shutting down." )
				stop()
			else
				handleUntrappedExceptionEvent( event )
			end
		end


		### Handle any reconfiguration events by re-reading the config
		### file and then reconnecting the listen socket.
		def handleReconfigEvent( event )
			results = []

			begin
				Thread.critical = true
				@config.reload
			rescue StandardError => e
				@log.error( "Exception encountered while reloading: #{e.to_s}" )
			ensure
				Thread.critical = false
			end

			# :FIXME: This may have problems, as events are delivered in a
			# thread whose $SAFE is probably going to preclude binding to
			# sockets, etc.
			@listenerMutex.synchronize( Sync::EX ) {
				oldListenerThread = @listenerThread
				oldListenerThread.raise Reload
				oldListenerThread.join

				@listenerThread = Thread.new { listenerThreadRoutine() }
				@listenerThread.abort_on_exception = true
			}

			return []
		end


		### Handle any system events that don't have explicit handlers.
		def handleSystemEvent( event )
			results = []

			case event
			when EngineShutdownEvent
				@log.notice( "Engine shut down by #{event.agent.to_s}." )
				stop()

			when GarbageCollectionEvent
				@log.notice( "Starting forced garbage collection." )
				GC.start

			else
				@log.notice( "Got a system event (a #{event.class.name}) " +
							 "that is not yet handled." )
			end

			return results
		end

		### Handle logging events by writing their content to the syslog.
		def handleLogEvent( event )
			@log.send( event.severity, event.message )
			return []
		end


		### Handle events for which we don't have an explicit handler.
		def handleUnknownEvent( event )
			@log.error( "Engine received unhandled event type '#{event.class.name}'." )
			return []
		end

	end # class Engine
end # module MUES


