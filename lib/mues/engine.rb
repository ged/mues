#!/usr/bin/ruby
# 
# This file contains the MUES::Engine class -- the main server class for the
# Multi-User Environment Server (MUES). The server encapsulates and provides a
# simple framework to accomplish the following tasks:
# 
# * Load, configure, and maintain one or more MUES::Environment objects.
# 
# * Handle system IO though an IO abstraction (MUES::IOEventStream) and a
#   polling loop.
#
# * Provide object persistance for user objects and environments
#   (MUES::ObjectStore).
#
# * Handle incoming connections using one or more configured protocols
#   represented by listener objects (MUES::Listener), login and authentication
#   (via MUES::LoginSession), and user objects (MUES::User).
# 
# * Coordinate, queue (MUES::EventQueue), and dispatch events (MUES::Event)
#   between the Environment objects, User objects, and other subsystems.
# 
# * Execute an event loop which serves as the fundamental unit of time for
#   each environment
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
#   config = MUES::Config::new( $ConfigFile )
#   engine = MUES::Engine::instance
# 
#   ### Start up and run the server
#   puts "Starting up...\n"
#   engine.start( config )
#   puts "Shut down...\n"
# 	
# === Subsystems
# 
# The Engine contains five basic kinds of functionality: system startup and
# shutdown, connections and IO, user authentication/authorization, event
# dispatch and handling, and environment maintenance functions.
# 
# ==== System Startup and Shutdown
# 
# The Engine is started by means of its #start method, and can be shut down
# either gracefully with the #shutdown method, allowing for its subsystems to
# save their state and clean up, or forcefully with the #halt method, which
# kills all threads immediately.
# 
# ==== Threads and Thread Routines
# 
# There are currently two thread routines in the Engine: the routines for the
# main thread of execution and the thread which drives IO. The main thread loops in the
# #mainThreadRoutine method, marking each loop by dispatching a
# MUES::TickEvent, and then sleeping for a duration of time set in the main
# configuration file. The #ioThreadRoutine method polls any socket added to the
# engine's poll object and calls the appropriate callback when an IO event
# occurs. This includes IO for both the MUES::Listener objects and
# MUES::OutputFilter objects in a MUES::IOEventStream.
#
# ==== User Authentication/Authorization
#
# When an incoming connection is detected on one of the Engine's MUES::Listener
# objects, the listener object creates a MUES::OutputFilter appropriate to the
# protocol it is listening for and dispatches a MUES::ListenerConnectEvent. The
# Engine then creates a MUES::LoginSession object, which gathers authentication
# information and dispatches a MUES::LoginSessionAuthEvent with it and two callbacks
# -- one for success and one for failure. The Engine looks up the MUES::User
# object of the user logging in, checks authentication and authorization, and
# calls the appropriate callback. On a successful login, the LoginSession
# creates a MUES::UserLoginEvent and dispatches it to the Engine, which creates
# a MUES::CommandShell for the user, and adds the user to its user table.
# 
# ==== Event Dispatch and Handling
# 
# The Engine contains the main dispatch mechanism for events in the server in
# the form of two MUES::EventQueue objects. An EventQueue is a prioritized
# scaling thread work crew object which accepts and executes events given to it
# by the server under a restricted permissions level. The Engine has a primary
# queue, which executes most events in the system, and a "privileged" queue,
# which executes events that require greater privileges (MUES::PrivilegedEvent
# objects). It fills these queues itself from the events that are given to its
# #dispatchEvents method.
#
# ==== Environments
#
# The Engine can host one or more MUES::Environment objects, which are loaded
# either via the server's configuration, or by a user from the command shell via
# a MUES::LoadEnvironmentEvent.
# 
# === Other Stuff
# 
# You can find more about the MUES project at http://mues.FaerieMUD.org/
# 
# == Rcsid
# 
# $Id: engine.rb,v 1.20 2002/09/27 16:12:33 deveiant Exp $
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

require "thread"
require "sync"
require "digest/md5"
require "poll"

require "mues/Mixins"
require "mues/Object"
require "mues/Config"
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
require "mues/Listener"
require "mues/PollProxy"

module MUES

	### MUES server class (Singleton)
	class Engine < MUES::Object ; implements MUES::Debuggable

		# Import type/safe-checking functions and the default event handler
		# dispatch method
		include MUES::TypeCheckFunctions,
			MUES::SafeCheckFunctions,
			MUES::UntaintingFunctions,
			MUES::Event::Handler


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

		### Default constants
		Version				= /([\d\.]+)/.match( %q{$Revision: 1.20 $} )[1]
		Rcsid				= %q$Id: engine.rb,v 1.20 2002/09/27 16:12:33 deveiant Exp $
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
			# @log 					= self.log						# MUES::Log (Log4r) Logger

			# Attributes
			@hostname				= nil
			@port					= nil
			@name					= DefaultName
			@admin					= DefaultAdmin
			@initMode				= false

			@state 					= State::STOPPED

			@startTime 				= nil
			@tick 					= 0

			@ioThread				= nil
			@ioMutex				= Sync::new
			@pollObj				= Poll::new
			@listeners				= {}

			@eventQueue				= nil
			@privilegedEventQueue	= nil
			@scheduledEvents		= ScheduledEventsHash.dup
			@scheduledEventsMutex	= Sync::new

			@users					= {}
			@usersMutex				= Sync::new

			@environments			= {}
			@environmentsMutex		= Sync::new

			@loginSessions			= []
			@loginSessionsMutex 	= Sync::new

			@exceptionStack			= []
			@exceptionStackMutex	= Sync::new

			@commandShellFactory	= nil
			@objectStore			= nil

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

		# Engine state flag (See MUES::Engine::State for values)
		attr_reader :state

		# The current server configuration (a MUES::Config object)
		attr_reader :config


		### Return (after potentially creating) the instance of the Engine,
		### which is a Singleton.
		def self.instance
			MUES::SafeCheckFunctions::checkSafeLevel( 2 )

			@@Instance = new() if ! @@Instance
			@@Instance
		end


		### Start the server using the specified configuration object (a
		### MUES::Config object). If <tt>initMode</tt> is true, accept an admin
		### connection from a user named 'admin' with no password for the
		### purposes of initialization.
		def start( config, initMode=false )
			checkType( config, MUES::Config )

			ignoreSignals()

			@initMode = initMode
			@state = State::STARTING
			@config = config
			startupEvents = []

			$stderr.puts "[Engine id is #{self.muesid}]"
			self.log.notice( "Starting Engine..." )

			# Set up the Engine
			startupEvents += setupEngine( config )

			# Now start up any other configured systems
			startupEvents += setupEnvironments( config )
			startupEvents += sendEngineStartupNotifications()
			startupEvents += setupListeners( config )
			startupEvents += setupIoThread( config )
			
			# Now enqueue any startup events
			self.log.info( "Dispatching %d events from startup" % startupEvents.length )
			self.dispatchEvents( *(startupEvents.flatten.compact) ) unless startupEvents.empty?

			# Reset the state to indicate we're running
			@state = State::RUNNING
			@startTime = Time.now
			self.log.notice( "Engine started. Start time is %s" % @startTime.to_s )

			### Start the event loop
			self.log.info( "Starting main thread routine." )
			mainThreadRoutine()
			self.log.info( "Done with main thread routine. Entering shutdown/cleanup." )

			return shutdown()
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


		### Returns +true+ if the server was started in 'init mode'.
		def initMode?
			return @initMode
		end


		### Shut the server down.
		def stop()
			self.log.notice( "Entering shutdown cycle" )
			@state = State::SHUTDOWN
		end


		### Check to be sure the Engine is running, and if not, raise an
		### exception with a message containing the specified <tt>action</tt>.
		def checkStateRunning( action="use it" )
			return true if self.running?

			action ||= "use it"
			raise RuntimeError,
				"The engine must be running to #{action}.",
				caller(1)
		end



		#############################################################
		###	E N V I R O N M E N T   A C C E S S O R S
		#############################################################

		### Returns an Arry of the names of the loaded environments
		def getEnvironmentNames
			return @environments.keys
		end


		### Fetch a running environment by +name+. Returns +nil+ if no such
		### environment is currently running.
		def getEnvironmentByName( name )
			checkSafeLevel( 3 )
			checkType( name, ::String )
			@environments[ name.downcase ]
		end


		### Fetch any running environments of the specified <tt>envClass</tt>,
		### which can be either a Class object or a String containing the name
		### of a class. If <tt>includeInherited</tt> is true, subclasses of the
		### specified class will also match.
		def getEnvironmentsByClass( envClass, includeInherited=false )
			checkSafeLevel( 3 )
			checkType( envClass, ::Class, ::String )

			if envClass.is_a?( ::String )
				envClass = MUES::Environment::getSubclass( envClass )
				return nil if envClass.nil?
			end

			@environments.find {|env|
				op = includeInherited ? :>= : :==
				env.class.send( op, envClass )
			}
		end



		#############################################################
		###	U S E R   A C C E S S O R S
		#############################################################

		### Fetch a list of the names of all users known to the server, both
		### connected and unconnected.
		def getUserNames
			checkSafeLevel( 3 )
			checkStateRunning( "get a list of user names" )
			@objectStore.indexKeys( :username )
		end


		### Fetch a list of the names of all connected users
		def getConnectedUserNames
			checkSafeLevel( 3 )
			@users.keys
		end


		### Fetch a connected user object by +name+. Returns +nil+ if no such
		### user is currently connected.
		def getUserByName( name )
			checkSafeLevel( 2 )
			checkStateRunning( "look up a user by name" )
			self.fetchUser( name.to_s )
		end


		### Add a new user (a MUES::User object) to the Engine's objectstore.
		def registerUser( user )
			checkSafeLevel( 2 )
			checkType( user, MUES::User )
			checkStateRunning( "register a new user" )
			@objectStore.store( user )
		end


		### Remove the specified user (a MUES::User oject) from the Engine's
		### objectstore.
		def unregisterUser( user )
			checkSafeLevel( 2 )
			checkType( user, MUES::User )
			checkStateRunning( "unregister a user" )
			@objectStore.remote( user )
		end



		#############################################################
		###	L I S T E N E R   A C C E S S O R S
		#############################################################

		### Fetch a listener object by +name+. Returns +nil+ if no such listener
		### is currently installed.
		def getListenerByName( name )
			checkSafeLevel( 3 )
			@listeners[ name.downcase ]
		end



		#############################################################
		###	G E N E R A L   I N F O R M A T I O N   M E T H O D S
		#############################################################

		### Return a multi-line string indicating the current status of the engine.
		def statusString
			status =	"#{@name}\n" 
			status +=	" MUES Engine %s\n" % [ Version ]
			status +=	" Up %0.2f seconds at tick %s " % [ Time.now - @startTime, @tick ]
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


		#############################################################
		###	E V E N T S   I N T E R F A C E
		#############################################################

		### Queue the given +events+ for dispatch.
		def dispatchEvents( *events )
			checkEachType( events, MUES::Event )
			checkStateRunning( "dispatch events" )

			# self.log.debug( "Dispatching #{events.length} events." )
			pevents = events.find_all {|ev| ev.kind_of?(MUES::PrivilegedEvent)}
			events -= pevents
			debugMsg( 5, "Dispatching %d regular events, %d privileged events." % 
					 [events.length, pevents.length] )

			@privilegedEventQueue.enqueue( *pevents )	unless pevents.empty?
			@eventQueue.enqueue( *events )				unless events.empty?
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
				self.log.info( "Removing all scheduled events." )
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




		#########
		protected
		#########

		### Configure the engine with the <tt>engine</tt> section of the
		### specified configuration (a MUES::Config object).
		def setupEngine( config )

			self.log.info( "Starting Engine setup." )
			setupEvents = []

			### Change working directory to that specified by the config file
			self.log.info( "Changing to root dir: %s" % @config.general.root_dir )
			Dir.chdir( @config.general.root_dir )
			
			### Set up subsystems
			setupEvents += setupLogging( config )
			setupEvents += setupObjectStore( config )
			setupEvents += setupEventHandlers( config )
			setupEvents += setupEventQueue( config )
			setupEvents += setupPrivilegedEventQueue( config )
			setupEvents += setupCommandShellFactory( config )

			# Set the server name to the one specified by the config
			@name = @config.general.server_name
			@admin = @config.general.server_admin

			return []
		end

		
		### Configure the logging subsystem (Log4r) according to the
		### <tt>logging</tt> section of the specified config (a MUES::Config
		### object).
		def setupLogging( config )
			self.log.info( "Setting up logging." )
			MUES::Log::configure( config )
		end


		### Set up the Engine's MUES::ObjectStore according to the specified
		### config (a MUES::Config object).
		def setupObjectStore( config )
			self.log.info( "Setting up Engine objecstore." )
			@objectStore = @config.createEngineObjectstore
			@objectStore.addIndexes( :class, :username )
			self.log.info( "Created Engine objectstore: #{@objectStore.to_s}" )
		end


		### Set up the Engine's event handlers
		def setupEventHandlers( config )
			# Register the server's handled event classes
			# :TODO: Register other event handlers
			self.log.info( "Setting up event handlers." )
			registerHandlerForEvents( self, 
									  EngineShutdownEvent,
									  ListenerConnectEvent, 
									  UntrappedExceptionEvent, 
									  LogEvent, 
									  SignalEvent,
									  UserEvent,
									  LoginSessionEvent,
									  EnvironmentEvent
									 )
		end


		### Set up the Engine's event queue according to the specified config (a
		### MUES::Config object).
		def setupEventQueue( config )

			### Start the event queue
			self.log.info( "Starting event queue." )
			@eventQueue = config.createEventQueue

			@eventQueue.debugLevel = 0
			@eventQueue.start( self )

			return []
		end


		### Set up the Engine's privileged event queue according to the
		### specified config (a MUES::Config object).
		def setupPrivilegedEventQueue( config )

			### Start the event queue
			self.log.info( "Starting privileged event queue." )
			@privilegedEventQueue = config.createPrivilegedEventQueue

			@privilegedEventQueue.debugLevel = 0
			@privilegedEventQueue.start( self )

			return []
		end


		### Set up the MUES::CommandShell::Factory used to create new user
		### command shells. It creates instances of the class specified in the
		### specified config (a MUES::Config object), which defaults to
		### MUES::CommandShell.
		def setupCommandShellFactory( config )
			
			### Create the factory
			self.log.info( "Creating command shell factory." )
			@commandShellFactory = config.createCommandShellFactory

			# Schedule an event to periodically update commands
			reloadEvent = CallbackEvent.new( @commandShellFactory.method('rebuildCommandRegistry') )
			self.scheduleEvents( @commandShellFactory.reloadInterval, reloadEvent ) if
				@commandShellFactory.reloadInterval.nonzero?

			return []
		end


		### Set up the preloaded environments specified in the given config (a
		### MUES::Config object).
		def setupEnvironments( config )
			self.log.info( "Setting up environments." )

			# Load the configured environment classes
			config.createConfiguredEnvironments.each {|env|
				@environmentsMutex.synchronize( Sync::EX ) {
					@environments[ env.name.downcase ] = env
				}
			}

			return []
		end


		### Set up the listener objects specified by the given config (a
		### MUES::Config object) in a dedicated thread.
		def setupListeners( config )
			self.log.info( "Setting up listeners." )

			@ioMutex.synchronize( Sync::EX ) {

				# Load the listeners from the configuration, installing each one
				# in the listeners hash
				self.log.info( "Creating configured listeners." )
				listeners = config.createConfiguredListeners
				self.log.info( "Got %d listeners from configuration." % listeners.length )
				self.addListeners( *listeners )
			}

			return []
		end


		### Set up and start the IO thread
		def setupIoThread( config )
			debugMsg( 1, "Starting IO thread." )

			@ioThread = Thread.new { ioThreadRoutine() }
			@ioThread.desc = "IO polling thread"
			@ioThread.abort_on_exception = true

			self.log.notice( "IO thread started: #{@ioThread.id}" )

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


		### Clear all signal handlers to their defaults.
		def clearSignalHandlers
			self.log.info( "Clearing signal handlers." )

			trap( "INT", "SIG_DFL" )
			trap( "TERM", "SIG_DFL" )
			trap( "HUP", "SIG_DFL" )
		end


		### Send notifications about the engine starting up to the classes which
		### have registered themselves as interested in receiving such
		### notification (by implementing MUES::Notifiable).
		def sendEngineStartupNotifications
			startupEvents = []

			# Notify all the Notifiables that we're started
			self.log.notice( "Sending onEngineStartup() notifications." )
			MUES::Notifiable.classes.each {|klass|
				res = klass.atEngineStartup( self )
				case res
				when Array
					startupEvents += res
				when MUES::Event
					startupEvents.push res
				else
					self.log.notice( "Ignoring unknown return type '%s' from %s.atEngineStartup" % [
									 res.type.name, klass.name ] )
				end
			}

			return startupEvents
		end

		
		### Create an environment specified by the given <tt>className</tt> and
		### install it in the list of running environments with the specified
		### <tt>instanceName</tt>. Returns any setup events that the environment
		### propagated when it was started, which should be propagated by the
		### caller.
		def loadEnvironment( className, instanceName )
			checkType( className, ::String, ::Class )
			checkType( instanceName, ::String )
			results = []

			instanceName.downcase!

			@environmentsMutex.synchronize( Sync::SH ) {

				# Make sure the environment specified isn't already loaded
				if @environments.has_key?( instanceName )
					raise EnvironmentLoadError,
						"Cannot load environment '#{instanceName}': Already loaded."

				else

					# Create the environment object
					self.log.notice( "Loading a '#{className}' environment as '#{instanceName}'" )
					environment = MUES::Environment::create( className, instanceName )
					checkType( environment, MUES::Environment )

					@environmentsMutex.synchronize( Sync::EX ) {
						self.log.notice( "Loaded the environment; Calling start on %s" % environment.to_s )
						results << environment.start()
						@environments[instanceName] = environment
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

			instanceName.downcase!

			@environmentsMutex.synchronize( Sync::SH ) {

				# Make sure the environment specified exists
				unless @environments.has_key?( instanceName )
					raise EnvironmentUnloadError,
						"Cannot unload environment '#{instanceName}': Not loaded."

				else

					# Unload the environment object, reporting any errors
					@environmentsMutex.synchronize( Sync::EX ) {
						results << @environments[instanceName].shutdown()
						@environments.delete( instanceName )
					}
				end
			}
			return results
		end


		### Add the specified listeners to the engine's hash of listeners and
		### register them with the poll object.
		def addListeners( *listeners )
			checkEachType( listeners, MUES::Listener )

			self.log.notice( "Adding %d listeners" % listeners.length )

			@ioMutex.synchronize( Sync::SH ) {
				listeners.each {|listener|
					@ioMutex.synchronize( Sync::EX ) {
						@listeners[ listener.name ] = listener
						registerListener( listener )
					}
				}
			}
		end


		### Remove the specified listeners (which may be either MUES::Listener
		### objects, or the names they're registered as) from the Engine's hash
		### of listeners, and unregister them from the poll object. Returns the
		### array of listeners which were removed.
		def removeListeners( *listeners )
			checkEachType( listeners, MUES::Listener, ::String )
			removed = []

			@ioMutex.synchronize( Sync::EX ) {
				listeners.each {|listener|
					listenerObj = nil

					# Attempt to remove it, either by fetching its name, if it's
					# a listener object, or using the argument as the name if
					# it's a string.
					case listener
					when MUES::Listener
						listenerObj = @listeners.delete( listener.name )

					when ::String
						listenerObj = @listeners.delete( listener.to_s )

					else
						raise MUES::Exception, "Unexpected listener type '#{listener.class.name}'"
					end

					# Unregister it if we actually removed something
					if listenerObj
						self.log.notice( "Removed listener %s" % listenerObj.to_s )
						unregisterListener( listenerObj )
						removed |= listenerObj
					else
						self.log.notice( "Could not remove listener #{listener.inspect}: Not registered." )
					end
				}
			}

			return removed
		end


		### Register the specified listener with the Engine's Poll object.
		def registerListener( listener )
			checkType( listener, MUES::Listener )

			self.log.info( "Registering listener: %s " % listener.to_s )

			# Define the callback Proc used for all Listeners if it isn't already defined
			@@ListenerConnectCallback ||= Proc::new {|sock,mask,listener|
				case mask

				# Normal readable event
				when Poll::IN
					self.log.notice( "Connect event for #{listener.to_s}." )

					filter = listener.createOutputFilter( @pollObj )
					self.dispatchEvents( ListenerConnectEvent::new(listener, filter) )

				# Error events
				when Poll::ERR|Poll::HUP|Poll::NVAL
					self.dispatchEvents( ListenerErrorEvent::new(listener, @pollObj, mask) )
					@pollObj.unregister( listener.io )

				# Everything else
				else
					self.log.error( "Unhandled Listener poll event #{mask.inspect}" )
				end
			}

			# Now register the listener with the poll object
			@ioMutex.synchronize( Sync::EX ) {
				@pollObj.register( listener.io, Poll::IN, @@ListenerConnectCallback, listener )
			}

			return true
		end


		### Un-register the specified listener with the Engine's Poll object
		def unregisterListener( listener )
			checkType( listener, MUES::Listener )

			self.log.info( "Unregistering listener: %s " % listener.to_s )

			@ioMutex.synchronize( Sync::EX ) {
				@pollObj.unregister( listener.io )
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
			tickLength = @config.engine.tick_length.to_f

			### Start the event loop until the engine stops running
			self.log.notice( "Starting event loop, tick length = #{tickLength}." )
			setupSignalHandlers( @config )
			while running? do
				begin
					@tick += 1
					debugMsg( 5, "In tick #{@tick}..." )
					pendingEvents = getPendingEvents( @tick )
					dispatchEvents( TickEvent.new(@tick), *pendingEvents ) 
				rescue StandardError => e
					if self.running?
						dispatchEvents( UntrappedExceptionEvent.new(e) )
					else
						self.log.error "Untrapped exception in main loop in a "\
							"non-running state: %s\n\t%s" %
							[ e.message, e.backtrace.join("\n\t") ]
					end
					next
				rescue Interrupt
					dispatchEvents( UntrappedSignalEvent.new("INT") )
				rescue SignalException => e
					dispatchEvents( UntrappedSignalEvent.new(e) )
				ensure
					sleep tickLength if self.running?
				end
			end
			self.log.notice( "Exiting event loop." )
			ignoreSignals()

			return @tick
		end


		### Shutdown routine for the main thread, once it exits the
		### #mainThreadRoutine.
		def shutdown
			cleanupEvents = []

			self.log.notice( "Stopping engine" )
			@state = State::SHUTDOWN

			### Shut down the listeners thread
			@ioThread.raise( Shutdown ) if @ioThread.alive?

			### Deactivate all users
			### :TODO: This should be more graceful, perhaps using UserLogoutEvents?
			@usersMutex.synchronize(Sync::EX) {
				@users.each_key do |user|
					cleanupEvents << user.deactivate
				end
			}

			# Notify all the Notifiables that we're shutting down
			self.log.notice( "Sending onEngineShutdown() notifications." )
			MUES::Notifiable.classes.each {|klass|
				debugMsg( 1, "Notifying #{klass.name} of shutdown." )
				rval = klass.atEngineShutdown( self )
				cleanupEvents += rval if rval.kind_of?( Array )
			}

			### Now enqueue any cleanup events as priority events (guaranteed to
			### be executed before the event queue returns from the shutdown()
			### call)
			cleanupEvents.flatten!
			cleanupEvents.compact!
			debugMsg( 1, "Got #{cleanupEvents.length} cleanup events." )
			@privilegedEventQueue.priorityEnqueue( *cleanupEvents ) unless cleanupEvents.empty?

			### Shut down the event queue
			clearSignalHandlers()
			self.log.notice( "Shutting down and cleaning up event queues" )
			@eventQueue.shutdown
			@privilegedEventQueue.shutdown

			### :TODO: Needs more thorough cleanup
			return true
		end


		### Routine for the thread that sets up and maintains the listener
		### socket.
		def ioThreadRoutine
			self.log.info( "Starting listener thread routine" )
			sleep 1 until running?

			while running? do
				begin

					if @config.engine.has_item? 'poll_interval'
						interval = @config.engine.poll_interval.to_f
					else
						interval = DefaultPollInterval
					end
					halfInterval = interval / 2

					self.log.info( "Half-interval is #{halfInterval}" )

					### :TODO: Fix race condition: If a connection comes in after stop()
					### has been called, but before the Shutdown exception has been
					### dispatched.
					while running? do

						Thread.pass
						sleep halfInterval

						begin
							@ioMutex.synchronize( Sync::SH ) {
								@pollObj.poll( 0.01 )
							}
						rescue StandardError => e
							dispatchEvents( UntrappedExceptionEvent.new(e) )
							Thread.pass
							next
						end

						Thread.pass
						sleep halfInterval

					end
				rescue Reload
					self.log.notice( "IO thread: Got notice of configuration reload." )
					next
				rescue Shutdown
					self.log.notice( "IO thread: Got notice of server shutdown." )
					break
				rescue StandardError => e
					dispatchEvents( UntrappedExceptionEvent.new(e) )
					next
				rescue Interrupt, SignalException => e
					dispatchEvents( UntrappedSignalEvent.new(e) )
					next
				end
			end

			self.log.notice( "Listener thread exiting." )
			return true
		end


		#############################################################
		###	O B J E C T S T O R E   I N T E R F A C E   M E T H O D S
		#############################################################

		### Fetch the user object for the specified <tt>username</tt> either
		### from the table of connected users, or from the Engine's object store
		### (MUES::ObjectStore). Returns <tt>nil</tt> if no such user exists.
		def fetchUser( username )
			self.log.info "Fetching user '#{username}'"

			@usersMutex.synchronize( Sync::SH ) {

				# Look up the user if there's not one already in the users table
				unless @users.keys.include? username
					self.log.info "Looking up user record for '#{username}'"
					@usersMutex.synchronize( Sync::EX ) {
						results = @objectStore.lookup( :class => MUES::User, :username => username )
						debugMsg( 2, "Results from user lookup => #{results.inspect}" )

						self.log.warn( "Lookup of user '#{username}' returned #{results.length} object" ) if
							results.length > 1
					
						self.log.info "Found #{results.length} results"
						@users[ username ] = results.shift unless results.empty?
					}
				end

				return @users[ username ]
			}
		end



		#############################################################
		###	E V E N T   H A N D L E R S
		#############################################################

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


		### Handle new filters created by an incoming connection on a
		### MUES::Listener by creating a MUES::LoginSession for it.
		def handleListenerConnectEvent( event )

			self.log.notice( "Handling new %s for %s: from %s" %
							 [event.filter.type.name,
							  event.listener.to_s,
							  event.filter.peerName] )

			### :TODO: Handle bans here


			### Create the event stream, add the new filters to the stream
			ios = IOEventStream::new
			ios.debugLevel = 0
			ios.addFilters( event.filter )

			### Create the login session and add it to our collection
			session = LoginSession::new( @config, ios, event.filter.peerName )
			session.debugLevel = 5
			@loginSessionsMutex.synchronize(Sync::EX) {
				@loginSessions.push session
			}

			return []
		end


		### Handle disconnections on filters created by listeners.
		def handleListenerCleanupEvent( event )
			results = event.listener.releaseOutputFilter( event.filter ) || []
			return *results
		end


		### Handle MUES::UserLoginEvent +event+.
		def handleUserLoginEvent( event )
			user = event.user

			results = []
			debugMsg( 3, "In handleUserEvent. Event is: #{event.to_s}" )

			stream = event.stream
			loginSession = event.loginSession

			# Set last login time and host in the user record
			user.lastLoginDate = Time.now
			user.lastHost = loginSession.remoteHost

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
				cshell.debugLevel = 5

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
			debugMsg( 3, "In handleUserDisconnectEvent. Event is: #{event.to_s}" )

			self.log.notice("User #{user.name} went link-dead.")
			@usersMutex.synchronize(Sync::EX) { @users[ user ]["status"] = "linkdead" }
			results << user.deactivate

			return results
		end


		### Handle MUES::UserIdleTimeoutEvent +event+ by disconnecting him.
		def handleUserIdleTimeoutEvent( event )
			user = event.user

			results = []
			debugMsg( 3, "In handleUserIdleTimeoutEvent. Event is: #{event.to_s}" )

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
			debugMsg( 3, "In handleUserLogoutEvent. Event is: #{event.to_s}" )

			self.log.notice("User #{user.to_s} disconnected.")
			@usersMutex.synchronize(Sync::EX) { @users.delete( user ) }
			user.deactivate

			return results
		end


		### Handle a user authentication attempt event.
		def handleLoginSessionAuthEvent( event )
			session = event.session
			remoteHost = event.remoteHost
			username = event.username
			password = event.password
			user = nil

			self.log.info( "Authentication event from session %s for %s@%s: %s" %
					   [ session.id, username, remoteHost, password.gsub(/./, '*') ] )
			results = []

			### :TODO: Check user bans

			# If we're running in init mode, and the user is logging in as
			# 'admin' create a dummy admin user.
			if self.initMode? && username == 'admin'
				self.log.notice( "ADMIN connection (init mode) from %s" % remoteHost )
				user = MUES::User::new( :accountType => 'admin',
									    :username => 'admin',
									    :realname => 'Init Mode Admin',
									    :emailAddress => 'muesadmin@localhost',
									    :lastLoginDate => Time::now,
									    :lastHost => remoteHost )
				results << event.successCallback.call( user )

			# Otherwise, try to fetch the user from the objecstore and authenticate her
			else
				user = self.fetchUser( username )
				debugMsg( 2, "Fetched user #{user.inspect} for '#{username}'" ) if user

				### Fail if no user was found by the name specified...
				if user.nil?
					self.log.notice( "Authentication failed for user '#{username}': No such user." )
					results << event.failureCallback.call( "No such user" )

					### ...or if the passwords don't match
				elsif user.cryptedPass != Digest::MD5::hexdigest( event.password )
					debugMsg( 1, "Bad password '%s': '%s' != '%s'" % [
								 event.password,
								 user.cryptedPass,
								 Digest::MD5::hexdigest( event.password )] )
					self.log.notice( "Authentication failed for user '#{username}': Bad password." )
					results << event.failureCallback.call( "Bad password" )

					### Otherwise succeed
				else
					self.log.notice( "User '#{username}' authenticated successfully." )
					results << event.successCallback.call( user )
				end
			end

			return results.flatten
		end


		### Handle a user authentication failure event.
		def handleLoginSessionFailureEvent( event )
			session = event.session
			self.log.notice( "Login session #{session.id} failed. Terminating." )

			session.terminate
			@loginSessionsMutex.synchronize(Sync::EX) {
				@loginSessions -= [ session ]
			}

			return []
		end


		### Handle LoadEnvironmentEvents by loading the specified environment.
		def handleLoadEnvironmentEvent( event )
			checkType( event, MUES::EnvironmentEvent )
			
			envClass = *untaint( event.envClassName, /([a-z][\w:]+)/i )
			envName  = *untaint( event.name, /(\w+)/ )
			results = self.loadEnvironment( envClass, envName )

			# Report success
			unless event.user.nil?
				event.user.handleEvent(OutputEvent.new( "Successfully loaded '#{envName}'\n\n" ))
			end

			return results
		rescue EnvironmentLoadError => e
			self.log.error( "%s: %s" % [e.message, e.backtrace.join("\t\n")] )

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
			self.log.error( "%s: %s" % [e.message, e.backtrace.join("\t\n")] )

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

			self.log.error( "Untrapped exception: %s: %s" % [
							   event.exception.to_s,
							   event.exception.backtrace.join("\n\t"),
						   ])
			return []
		end


		### Handle trapped signals.
		def handleSignalEvent( event )
			self.log.crit( "Caught SIG#{event.signal}" )

			case event.signal

			when "HUP"
				self.dispatchEvents( MUES::ReconfigEvent::new )

			when "TERM", "INT"
				self.dispatchEvents( MUES::EngineShutdownEvent::new(event) )

			else
				self.log.error( "I don't know how to handle #{event.signal} signals. Ignoring." )
			end
		end


		### Handle untrapped signals.
		def handleUntrappedSignalEvent( event )
			self.log.crit( "Caught untrapped signal #{event.signal}: Shutting down." )
			stop()
		end


		### Handle any reconfiguration events by re-reading the config
		### file and then reconnecting the listen socket.
		def handleReconfigEvent( event )
			results = []

			begin
				Thread.critical = true
				@config.reload
			rescue StandardError => e
				self.log.error( "Exception encountered while reloading: #{e.to_s}" )
			ensure
				Thread.critical = false
			end

			# :FIXME: This may have problems, as events are delivered in a
			# thread whose $SAFE is probably going to preclude binding to
			# sockets, etc.
			@ioMutex.synchronize( Sync::EX ) {
				oldListenerThread = @ioThread
				oldListenerThread.raise Reload
				oldListenerThread.join

				setupIoThread( @config )
			}

			return []
		end


		### Handle any system events that don't have explicit handlers.
		def handleSystemEvent( event )
			results = []

			case event
			when EngineShutdownEvent
				self.log.notice( "Starting engine shutdown for #{event.agent.to_s}." )
				stop()

			when GarbageCollectionEvent
				self.log.notice( "Starting forced garbage collection." )
				GC.start

			else
				self.log.notice( "Got a system event (a #{event.class.name}) " +
							 "that is not yet handled." )
			end

			return results
		end

		### Handle logging events by writing their content to the syslog.
		def handleLogEvent( event )
			self.log.send( event.severity, event.message )
			return []
		end


		### Handle events for which we don't have an explicit handler.
		def handleUnknownEvent( event )
			self.log.error( "Engine received unhandled event type '#{event.class.name}'." )
			return []
		end

	end # class Engine
end # module MUES


