#!/usr/bin/env ruby
#################################################################
=begin  

= Engine

== Name

Engine.rb - The server class for the MUES system

== Synopsis

  #!/usr/bin/ruby

  require "mues/Config"
  require "mues/Engine"

  $ConfigFile = "MUES.cfg"

  ### Instantiate the configuration and the server objects
  config = MUES::Config.new( $ConfigFile )
  engine = MUES::Engine.instance

  ### Start up and run the server
  puts "Starting up...\n"
  engine.start( config )
  puts "Shut down...\n"
	
== Description

This class is the main server class for the Multi-User Environment Server
(MUES). The server encapsulates and provides a simple front end/API for the
following tasks:

* Load, configure, and maintain one or more Environment objects, each of which
  contains a class library made up of metaclasses stored in a database

* Handle user connection, login, and user object maintenance through a
  client protocol or simple telnet/HTTP connection

* Maintain one or more game Sciences, which provide shared event-driven
  services to the hosted game environments

* Coordinate, queue, and dispatch Events between the Environment objects, User
  objects, and the Sciences.

* Execute an event loop which serves as the fundamental unit of time for
  each environment

=== Subsystems

The Engine contains four basic kinds of functionality: thread routines, event
dispatch and handling routines, system startup/shutdown routines, and
environment interaction functions.

==== Threads and Thread Routines

There are currently two thread routines in the Engine: the routines for the main
thread of execution and the listener socket. The main thread loops in the
((<MUES::Engine#_mainThreadRoutine>)) method, marking each loop by dispatching a
((<MUES::TickEvent>)), and then sleeping for a duration of time set in the main
configuration file. The listener socket also has a thread dedicated to it which
runs in the ((<MUES::Engine#_listenerThreadRoutine>)) method. This thread waits
on a call to accept() for an incoming connection, and dispatches a
SocketConnectEvent for each client.

==== Event Dispatch and Handling

The Engine contains the main dispatch mechanism for events in the server in the
form of a (({MUES::EventQueue})). This class is a prioritized scaling thread
work crew class which accepts and executes events given to it by the server.

==== System Startup and Shutdown

The Engine is started by means of its start method

=== Other Stuff

More comprehensive documentation to follow, but in the meantime, you can find
the working copy at:
((<URL:http://docs.faeriemud.org/bin/view/Dream/TheEngine>)).

== Modules
=== MUES::Engine::State

Namespace for the Engine state constants. (See ((<MUES::Engine#state>)) for more
information.)

== Classes

=== MUES::Engine
==== Class Methods

--- MUES::Engine.instance

    Returns the singleton instance of the Engine object, creating it if necessary.

==== Public Methods

--- MUES::Engine#hostname

    Returns the hostname (a (({String}))) the engine is listening on as set in
    the config file. ((*Read-only*))

--- MUES::Engine#port

    Returns the port (a (({String}))) the engine is bound to as set in the
    config file. ((*Read-only*))

--- MUES::Engine#name

    Returns the name (a (({String}))) the server will display when connecting as
    set in the configuration file. ((*Read-only*))

--- MUES::Engine#log

    Returns the log handle (a ((<MUES::Log>)) instance) the engine is using. ((*Read-only*)).

--- MUES::Engine#users

    Returns the hash of hashes which tracks the status of currently connected
    users, keyed by user object (a ((<MUES::User>)) instance). Each entry
    is of the form:

      <a MUES::User> => {
        'status'    => ('connecting'|'active'|'linkdead') (a String),
        'loginTime' => <a Time object created at login>
      }

--- MUES::Engine#connections

    Returns the array which contains IOEventStreams for incoming connections
    which still haven^t logged in.

--- MUES::Engine#state

    Returns the state of the engine, which will be one of:

      : ((|MUES::Engine::State::STOPPED|))

        Engine is stopped. It will not answer connections on any port, and it
        has no threads running.

      : ((|MUES::Engine::State::STARTING|))

        The engine is starting up. It will begin answering connections on its
        listen port at the end of this state.

      : ((|MUES::Engine::State::RUNNING|))

        The engine is running, and it will answer connections on its main listen
        port. This is the normal state of operation.

      : ((|MUES::Engine::State::SHUTDOWN|))

        The engine is shutting down. It will stop answering connections,
        deactivate all connected users, and stop all running threads.

--- MUES::Engine#start( config )

    Starts the engine with the configuration values specified in the given
    config object, which should be an instance of MUES::Config or a derivative
    class.

--- MUES::Engine#started?

    Returns (({true})) if the engine is in any state except
    ((<State::STOPPED>)).

--- MUES::Engine#getEnvironmentNames

	Returns an array of loaded environment names.

--- MUES::Engine#getEnvironment( name )

	Returns the loaded environment object associated with the specified name, or
	(({nil})) if no such environment exists.

--- MUES::Engine#loadEnvironment( className[, envName] )

	Load an instance of the specified Environment class and associate it with
	the specified name.

--- MUES::Engine#running?

    Returns true if the engine is in the ((<State::RUNNING>)) state.

--- MUES::Engine#stop()

    Start the Engine^s shutdown sequence.

--- MUES::Engine#scheduleEvents( time, *events )

    Schedule the specified events to be dispatched at the time specified. If
    ((|time|)) is a (({Time})) object, it will be executed at the tick which
    occurs at or immediately after the specified time. If ((|time|)) is a
    positive (({Integer})), it is assumed to be a tick offset, and the event
    will be dispatched ((|time|)) ticks from now.  If ((|time|)) is a negative
    (({Integer})), it is assumed to be a repeating event which requires dispatch
    every (({time.abs})) ticks.

--- MUES::Engine#cancelScheduledEvents( *events )

    Removes and returns the specified scheduled ((|events|)), if found.

--- MUES::Engine#dispatchEvents( *events )

    Queue the given ((|events|)) for dispatch.

--- MUES::Engine#statusString()

    Returns a multi-line string indicating the current status of the engine.


==== Protected Methods

--- MUES::Engine#initialize()

    Sets up and initialize the Engine instance.

--- MUES::Engine#_mainThreadRoutine()

    The main event loop. This is the routine that the main thread runs,
    dispatching ((<MUES::TickEvent>))s for timing. Exits and returns the total
    number of ticks to the caller after ((<MUES::Engine#stop>)) is called.

--- MUES::Engine#_listenerThreadRoutine()

    The thread routine for the listener thread which accept()s on the main
    socket and dispatches a new ((<MUES::SocketConnectEvent>))s for each
    connection.

--- MUES::Engine#_setupListenerSocket( host, port, tcpWrapperedFlag )

    Returns a listener socket for the specified ((|host|)) and ((|port|)). If
    the ((|tcpWrapperedFlag|)) is (({true})), the returned socket is wrapped
    inside an instance of (({TCPWrapper})); otherwise, it is an instance of
    (({TCPServer})).

--- MUES::Engine#_getPendingEvents( tickNumber )

    Returns an (({Array})) of events which are pending execution for the
    ((|tickNumber|)) specified.

--- MUES::Engine#_handleEnvironmentEvent( event )

    Event handler for ((<MUES::EnvironmentEvent>))s.

--- MUES::Engine#_handleSocketConnectEvent( event )

    Event handler for ((<MUES::SocketConnectEvent>))s.

--- MUES::Engine#_handleUserEvent( event )

    Event handler for ((<MUES::UserEvent>))s.

--- MUES::Engine#_handleUntrappedExceptionEvent( event )

    Event handler for ((<MUES::UntrappedExceptionEvent>))s.

--- MUES::Engine#_handleUntrappedSignalEvent( event )

    Event handler for ((<MUES::UntrappedSignalEvent>))s.

--- MUES::Engine#_handleLoginSessionAuthEvent( event )

    Event handler for ((<MUES::LoginSessionAuthEvent>))s.

--- MUES::Engine#_handleLoginSessionFailureEvent( event )

    Event handler for ((<MUES::LoginSessionFailureEvent>))s.

--- MUES::Engine#_handleReconfigEvent( event )

    Event handler for ((<MUES::ReconfigEvent>))s.

--- MUES::Engine#_handleSystemEvent( event )

    Event handler for ((<MUES::SystemEvent>))s.

--- MUES::Engine#_handleLogEvent( event )

    Event handler for ((<MUES::LogEvent>))s.

--- MUES::Engine#_handleEvent( event )

    Event handler for events without an explicit handler.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>
and Jeremiah Chase <((<phaedrus@FaerieMUD.org|URL:mailto:phaedrus@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "socket"
require "thread"
require "sync"
require "md5"

require "mues/Namespace"
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

	### MUES Engine (server) class
	class Engine < Object ; implements Debuggable

		### State constants
		module State
			STOPPED		= 0
			STARTING	= 1
			RUNNING		= 2
			SHUTDOWN	= 3
		end

		# Import the default event handler dispatch method
		include Event::Handler

		### Default constants
		Version			= /([\d\.]+)/.match( %q$Revision: 1.12 $ )[1]
		Rcsid			= %q$Id: engine.rb,v 1.12 2001/11/01 17:02:01 deveiant Exp $
		DefaultHost		= 'localhost'
		DefaultPort		= 6565
		DefaultName		= 'ExperimentalMUES'
		DefaultAdmin	= 'MUES Admin <mues@localhost>'

		ScheduledEventsHash = { 'timed' => {}, 'ticked' => {}, 'repeating' => {} }

		### Class variables
		@@Instance		= nil

		### Make the new method private, as this class is a singleton
		private_class_method :new

		### Initialization method
		protected

		### (PROTECTED) METHOD: initialize
		### Initialize the Engine instance.
		def initialize
			@config = nil
			@log = nil

			@listenerThread = nil
			@listenerMutex = Sync.new

			@hostname = DefaultHost
			@port = DefaultPort
			@name = DefaultName
			@admin = DefaultAdmin

			@eventQueue = nil
			@scheduledEvents = ScheduledEventsHash.dup
			@scheduledEventsMutex = Sync.new

			@users				= {}
			@usersMutex			= Sync.new
			@environments		= {}
			@environmentsMutex	= Sync.new

			@loginSessions = []
			@loginSessionsMutex = Sync.new

			@exceptionStack = []
			@exceptionStackMutex = Sync.new

			@state = State::STOPPED
			@startTime = nil
			@tick = nil

			@engineObjectStore = nil

			super()
		end

		###########################################################
		###	P U B L I C   I N S T A N C E   M E T H O D S
		###########################################################
		public

		### Read-only accessors for instance variables
		attr_reader :hostname, :port, :name, :log, :users, :connections, :state, :config

		### (CLASS) METHOD: instance
		### Returns (and potentially creates) the instance of the Engine, which
		### is aSingleton.
		def Engine.instance

			### :TODO: Put access-checking here to prevent any old thing from getting the instance

			@@Instance = new() if ! @@Instance
			@@Instance
		end


		### METHOD: start( aConfig )
		### Start the server using the specified configuration
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


		### METHOD: started?()
		### Return true if the server is currently started or running
		def started?
			return @state == State::STARTING || running?
		end


		### METHOD: running?()
		### Return true if the server is currently running
		def running?
			return @state == State::RUNNING
		end


		### METHOD: stop()
		### Shut the server down
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


		### METHOD: getEnvironmentNames
		### Get a list of the names of the loaded environments
		def getEnvironmentNames
			return @environments.keys
		end

		### METHOD: getEnvironment( aNameString )
		### Get the loaded environment with the specified name.
		def getEnvironment( name )
			checkType( name, ::String )
			return @environments[name]
		end


		### METHOD: loadEnvironment( className[, envName] )
		### Load an instance of the specified Environment class and associate it
		### with the specified name.
		def loadEnvironment( className, envName=nil )
			checkType( className, ::String )

			klass = nil
			unless (( klass = Module::constants.find {|const| const == className} ))
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


		### METHOD: dispatchEvents( *events )
		### Queue the given events for dispatch
		def dispatchEvents( *events )
			checkEachType( events, MUES::Event )
			# @log.debug( "Dispatching #{events.length} events." )
			@eventQueue.enqueue( *events )
		end


		### METHOD: scheduleEvents( time, *events )
		### Schedule the specified events to be dispatched at the time
		### specified. If ((|time|)) is a (({Time})) object, it will be executed
		### at the tick which occurs closest to the specified time. If
		### ((|time|)) is a positive (({Integer})), it is assumed to be a tick
		### offset, and the event will be dispatched ((|time|)) ticks from now.
		### If ((|time|)) is a negative (({Integer})), it is assumed to be a
		### repeating event which requires dispatch every (({time.abs})) ticks.
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


		### METHOD: cancelScheduledEvents( *events )
		### Removes and returns the specified scheduled events, if found.
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


		### METHOD: statusString
		### Return a multi-line string indicating the current status of the engine
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


		### Protected methods
		protected

		### (PROTECTED) METHOD: _setupListenerSocket( host, port, tcpWrapperedFlag )
		### Set up and return a listener socket (TCPServer) object on the specified host and port, 
		### optionally wrapped in a TCPWrapper object
		def _setupListenerSocket( host = DefaultHost, port = DefaultPort, tcpWrappered = false )
			listener = nil

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


		### (PROTECTED) METHOD: _getPendingEvents( tickNumber )
		### Returns an (({Array})) of events which are pending execution for the
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

		### (PROTECTED) METHOD: _mainThreadRoutine()
		### The main event loop. This is the routine that the main thread runs,
		### dispatching pending scheduled events and TickEvents for
		### timing. Exits and returns the total number of ticks to the caller
		### after stop() is called.
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


		### (PROTECTED) METHOD: _listenerThreadRoutine()
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

			listener.shutdown( 2 )
			listener.close

			@log.notice( "Listener thread exiting." )
		end


		#############################################################
		###	E V E N T   H A N D L E R S
		#############################################################

		### (PROTECTED) METHOD: _handleSocketConnectEvent( event )
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


		### (PROTECTED) METHOD: _handleUserEvent( event )
		### Handle changes to user status
		def _handleUserEvent( event )
			user = event.user

			results = []
			@log.debug( "In _handleUserEvent. Event is: #{event.to_s}" )

			### Handle the different user events
			case event

			when UserLoginEvent
				stream = event.stream
				loginSession = event.loginSession

				# Set last login time and host in the user record
				user.lastLogin = Time.now
				user.remoteHost = loginSession.remoteHost

				### If the user object is already active (ie., already
				### connected and has a shell), remove the old socket connection
				### and re-connect with the new one. Otherwise, just activate
				### the user object.
				if user.activated?
					results << LogEvent.new( "notice", "User #{user.to_s} reconnected." )
					results << user.reconnect( stream )
				else
					results << LogEvent.new( "notice", "Login succeeded for #{user.to_s}." )
					results << user.activate( stream )
				end

				# Add the activated user to our userlist, and remove the spent
				# login session from our list of active logins
				@usersMutex.synchronize(Sync::EX) {
					@users[ user ] = { "status" => "active" }
				}
				@loginSessionsMutex.synchronize( Sync::EX ) {
					@loginSessions -= [ loginSession ]
				}

			when UserDisconnectEvent
				results << LogEvent.new("notice", "User #{user.name} went link-dead.")
				@usersMutex.synchronize(Sync::EX) { @users[ user ]["status"] = "linkdead" }
				results << user.deactivate

			when UserIdleTimeoutEvent
				results << LogEvent.new("notice", "User #{user.name} disconnected due to idle timeout.")
				# @usersMutex.synchronize {	@users[ user ]["status"] = "linkdead" }
				@usersMutex.synchronize(Sync::EX) { @users.delete( user ) }
				user.deactivate

			when UserLogoutEvent
				results << LogEvent.new("notice", "User #{user.to_s} disconnected.")
				@usersMutex.synchronize(Sync::EX) { @users.delete( user ) }
				user.deactivate

			when UserSaveEvent
				@log.debug( "In UserSaveEvent handler for #{user.to_s}" )
				results << LogEvent.new("info", "Saving record for user #{user.to_s}.")
				@log.debug( "Finished adding LogEvent to results array." )
				begin
					@log.debug( "About to call storeUser()." )
					@engineObjectStore.storeUser( user )
					@log.debug( "Back from storeUser()." )
					results << LogEvent.new("info", "Saved user record for #{user.to_s}")
					@log.debug( "Added LogEvent to results array." )
				rescue Exception => e
					@log.error( "Error while saving #{user.to_s}: ", e.backtrace.join("\n") )
					results << LogEvent.new("error", "Exception while storing user record for #{user.to_s}")
					### :TODO: Perhaps dump to a rescue file or something?
				end

			else
				_handleEvent( event )
			end

			return results
		end


		### (PROTECTED) METHOD: _handleLoginSessionAuthEvent( event )
		### Handle a user authentication attempt event
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


		### (PROTECTED) METHOD: _handleLoginSessionFailureEvent( event )
		### Handle a user authentication failure event
		def _handleLoginSessionFailureEvent( event )
			session = event.session
			logEvent = LogEvent.new("notice", "Login session #{session.id} failed. Terminating.")

			session.terminate
			@loginSessionsMutex.synchronize(Sync::EX) {
				@loginSessions -= [ session ]
			}

			return [ logEvent ]
		end


		### (PROTECTED) METHOD: _handleEnvironmentEvent( event )
		### Handle environment events
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


		### (PROTECTED) METHOD: _handleUntrappedExceptionEvent( event )
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
			
			[ LogEvent.new( "error", "Untrapped exception: ",
						   event.exception.to_s, "\n\t", 
						   event.exception.backtrace.join("\n\t") ) ]
		end


		### (PROTECTED) METHOD: _handleUntrappedSignalEvent( event )
		### Handle untrapped signals.
		def _handleUntrappedSignalEvent( event )
			if event.exception.is_a?( Interrupt ) then
				@log.crit( "Caught interrupt. Shutting down." )
				stop()
			else
				_handleUntrappedExceptionEvent( event )
			end
		end


		### (PROTECTED) METHOD: _handleReconfigEvent( event )
		### Handle any reconfiguration events by re-reading the config
		### file and then reconnecting the listen socket 
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


		### (PROTECTED) METHOD: _handleSystemEvent( event )
		### Handle any system events that don't have explicit handlers
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

		### (PROTECTED) METHOD: _handleLogEvent( event )
		### Handle logging events by writing their content to the syslog
		def _handleLogEvent( event )
			@log.send( event.severity, event.message )
			return []
		end


		### (PROTECTED) METHOD: _handleEvent( event )
		### Handle events which we get sent for which we don't have an explicit handler
		def _handleUnknownEvent( event )
			@log.error( "Engine received unhandled event type '#{event.class.name}'." )
			return []
		end

	end # class Engine
end # module MUES


