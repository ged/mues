#!/usr/bin/env ruby
###########################################################################
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

* Load, configure, and maintain one or more World objects, each of which
  contains a class library made up of metaclasses stored in a database

* Handle player connection, login, and player object maintenance through a
  client protocol or simple telnet/HTTP connection

* Maintain one or more game Sciences, which provide shared event-driven
  services to the hosted game worlds

* Coordinate, queue, and dispatch Events between the World objects, Player
  objects, and the Sciences.

* Execute an event loop which serves as the fundamental unit of time for
  each world

=== Subsystems

The Engine contains three basic kinds of functionality: thread routines, event
dispatch and handling routines, and system startup/shutdown routines.

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

=== Other Stuff

More comprehensive documentation to follow, but in the meantime, you can find
the working copy at:
((<URL:http://docs.faeriemud.org/bin/view/Dream/TheEngine>)).

== Methods
=== MUES::Engine
==== Class Methods

--- MUES::Engine.instance()

    Returns the singleton instance of the Engine object, creating it if necessary.

==== Protected Instance Methods

--- MUES::Engine#initialize()

    Sets up and initializes the engine instance.

==== Instance Methods

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

--- MUES::Engine#players

    Returns the hash of hashes which tracks the status of currently connected
    players, keyed by player object (a (({MUES::Player})) instance). Each entry
    is of the form:

      (({MUES::Player})) => {
        'status'    => <((|connecting|active|linkdead|))> (a (({String}))),
        'loginTime' => (a (({Time})) object created at login)
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
        disconnect all connected players, and stop all running threads.

--- MUES::Engine#start( config )

    Starts the engine with the configuration values specified in the given
    config object, which should be an instance of MUES::Config or a derivative
    class.

--- MUES::Engine#started?

    Returns (({true})) if the engine is in any state except
    ((<State::STOPPED>)).

--- MUES::Engine#running?

    Returns true if the engine is in the ((<State::RUNNING>)) state.

--- MUES::Engine#stop()

    Shuts the engine/server down.

--- MUES::Engine#dispatchEvents( *events )

    Queue the given ((|events|)) for dispatch.

--- MUES::Engine#statusString()

    Returns a multi-line string indicating the current status of the engine.

==== Protected Instance Methods

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

--- MUES::Engine#_handleSocketConnectEvent( event )

    Event handler for ((<MUES::SocketConnectEvent>))s.

--- MUES::Engine#_handlePlayerEvent( event )

    Event handler for ((<MUES::PlayerEvent>))s.

--- MUES::Engine#_handleUntrappedExceptionEvent( event )

    Event handler for ((<MUES::UntrappedExceptionEvent>))s.

--- MUES::Engine#_handleUntrappedSignalEvent( event )

    Event handler for ((<MUES::UntrappedSignalEvent>))s.

--- MUES::Engine#_handleReconfigEvent( event )

    Event handler for ((<MUES::ReconfigEvent>))s.

--- MUES::Engine#_handleSystemEvent( event )

    Event handler for ((<MUES::SystemEvent>))s.

--- MUES::Engine#_handleLogEvent( event )

    Event handler for ((<MUES::LogEvent>))s.

--- MUES::Engine#_handleUnknownEvent( event )

    Event handler for events without an explicit handler.

== AUTHOR

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>
and Jeremiah Chase <((<phaedrus@FaerieMUD.org|URL:mailto:phaedrus@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "socket"
require "thread"
require "sync"
require "md5"

require "mues/Namespace"
require "mues/Log"
require "mues/EventQueue"
require "mues/Exceptions"
require "mues/Events"
require "mues/Player"
require "mues/IOEventStream"
require "mues/IOEventFilters"
require "mues/ObjectStore"
require "mues/World"
require "mues/LoginSession"
require "mues/Debugging"

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
		Version			= /([\d\.]+)/.match( %q$Revision: 1.8 $ )[1]
		Rcsid			= %q$Id: engine.rb,v 1.8 2001/06/25 14:03:14 deveiant Exp $
		DefaultHost		= 'localhost'
		DefaultPort		= 6565
		DefaultName		= 'ExperimentalMUES'
		DefaultAdmin	= 'MUES Admin <mues@localhost>'

		### Class variables
		@@Instance		= nil

		### Make the new method private, as this class is a singleton
		private_class_method :new

		### Initialization method
		protected
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
			@scheduledEvents = { 'timed' => {}, 'ticked' => {}, 'repeating' => {} }
			@scheduledEventsMutex = Sync.new

			@players = {}
			@playersMutex = Sync.new

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

		###############################################################################
		###	P U B L I C   I N S T A N C E   M E T H O D S
		###############################################################################
		public

		### Read-only accessors for instance variables
		attr_reader :hostname, :port, :name, :log, :players, :connections, :state, :config

		### (STATIC) METHOD: instance( )
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

			### Change working directory to that specified by the config file
			#Dir.chdir( @config["rootdir"] )
			
			# Set the server name to the one specified by the config
			@name = @config["name"]
			@admin = @config["admin"]

			### Sanity-check the log handle and assign it
			@log = Log.new( @config["rootdir"] + "/" + @config["logfile"] )
			@log.notice( "Engine startup for #{@name} at #{Time.now.to_s}" )

			### Connect to the MUES objectstore
			@log.info( "Creating Engine objectstore: %s %s@%s" % [
						  @config['objectstore']['driver'],
						  @config['objectstore']['db'],
						  @config['objectstore']['host']
					  ])
			@engineObjectStore = ObjectStore.new( @config["objectstore"]["driver"],
												  @config["objectstore"]["db"],
												  @config["objectstore"]["host"],
												  @config["objectstore"]["username"],
												  @config["objectstore"]["password"] )

			### Register the server as being interested in a couple of different events
			@log.info( "Registering engine event handlers." )
			registerHandlerForEvents( self, 
									  EngineShutdownEvent,
									  SocketConnectEvent, 
									  UntrappedExceptionEvent, 
									  LogEvent, 
									  UntrappedSignalEvent,
									  PlayerEvent,
									  LoginSessionEvent
									 )
			
			### :TODO: Register other event handlers

			### Start the event queue
			@log.info( "Starting event queue." )
			@eventQueue = EventQueue.new( @config["eventqueue"]["minworkers"], 
										  @config["eventqueue"]["maxworkers"],
										  @config["eventqueue"]["threshold"] )
			@eventQueue.debugLevel = 1
			@eventQueue.start

			### Set up a listener socket on the specified port
			@log.info( "Starting listener thread." )
			@listenerMutex.synchronize( Sync::EX ) {
				@listenerThread = Thread.new { _listenerThreadRoutine }
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

			### Disconnect all players
			### :TODO: This should be more graceful, perhaps using PlayerLogoutEvents?
			@playersMutex.synchronize(Sync::EX) {
				@players.each_key do |player|
					cleanupEvents << player.disconnect
				end
			}

			### Now queue up any cleanup events and dispatch 'em
			cleanupEvents.flatten!
			@eventQueue.priorityEnqueue( *cleanupEvents ) unless cleanupEvents.empty?

			### Shut down the event queue
			@log.info( "Shutting down and cleaning up event queue" )
			@eventQueue.shutdown

			### :TODO: Needs more shutdown stuff
		end


		### METHOD: dispatchEvents( *events )
		### Queue the given events for dispatch
		def dispatchEvents( *events )
			checkEachType( events, MUES::Event )
			@log.debug( "Dispatching #{events.length} events." )
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
				@log.debug( "Scheduling #{events.length} events for #{time} (Time)" )

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

				# Repeating events -- keyed with an array of two elements: the
				# number of the next tick at which the events should be
				# dispatched, and the interval at which they run
				if time < 0
					tickInterval = time.abs
					nextTick = @tick + interval
					@log.debug( "Scheduling #{events.length} events to repeat every " +
							    "#{tickInterval} ticks (next at #{nextTick})" )
					@scheduledEventsMutex.synchronize(Sync::EX) {
						@scheduledEvenst['repeating'][[ nextTick, tickInterval ]] ||= []
						@scheduledEvenst['repeating'][[ nextTick, tickInterval ]] += events
					}

				# One-time tick-fired events, keyed by tick number
				elsif time > 0
					time = time.abs
					time += @tick
					@log.debug( "Scheduling #{events.length} events for tick #{time}" )
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
				@scheduledEventsMutex.synchronize(Sync::EX) {
					@scheduledEvents = { 'timed' => [], 'ticked' => [], 'repeating' => {} }
				}

			# Remove just the events specified
			else
				@scheduledEventsMutex.synchronize(Sync::EX) {
					@scheduledEvents.each {|type,eventHash|
						eventHash.each {|time,eventArray|
							eventArray -= events
							### :TODO: Clear out blank schedule entries
						}
					}
				}
			end
		end


		### METHOD: statusString
		### Return a multi-line string indicating the current status of the engine
		def statusString
			status =	"#{@name}\n"
			status +=	" MUES Engine %s\n" % [ Version ]
			status +=	" Up %.2f seconds at tick %s " % [ Time.now - @startTime, @tick ]
			status +=	" %d players logging in\n" % [ @loginSessions.length ]
			@playersMutex.synchronize(Sync::SH) {
				status +=	" %d players active, %d linkdead\n\n" % 
					[ @players.find_all {|pl,st| st["status"] == "active"}.size,
					  @players.find_all {|pl,st| st["status"] == "linkdead"}.size ]
				status +=	"\n Players:\n"
				@players.keys.each {|player|
					status += "  #{player.to_s}\n"
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


		#######################################################################
		###	T H R E A D   R O U T I N E S
		#######################################################################

		### (PROTECTED) METHOD: _mainThreadRoutine()
		### The main event loop. This is the routine that the main thread runs,
		### dispatching pending scheduled events and TickEvents for
		### timing. Exits and returns the total number of ticks to the caller
		### after stop() is called.
		def _mainThreadRoutine

			@tick = 0

			### Start the event loop until the engine stops running
			@log.notice( "Starting event loop." )
			while running? do
				begin
					@tick += 1
					@log.debug( "In tick #{@tick}..." )
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
					playerSock = listener.accept
					@log.info( "Connect from #{playerSock.addr[2]}" )
					dispatchEvents( SocketConnectEvent.new(playerSock) )
				rescue Errno::EPROTO
					dispatchEvents( LogEvent.new("error", "Accept failed (EPROTO).") )
					next
				rescue Reload
					dispatchEvents( LogEvent.new("notice", "Got notice of configuration reload.") )
					break
				rescue Shutdown
					dispatchEvents( LogEvent.new("notice", "Got notice of server shutdown.") )
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


		#######################################################################
		###	E V E N T   H A N D L E R S
		#######################################################################

		### (PROTECTED) METHOD: _handleSocketConnectEvent( event )
		### Handle connections to the listener socket.
		def _handleSocketConnectEvent( event )
			results = []
			results.push LogEvent.new("Socket connect event from '#{event.socket.addr[2]}'.")

			### :TODO: Handle bans here

			### Copy the event's socket to dynamic variable, and create a socket
			### output filter
			sock = event.socket
			soFilter = SocketOutputFilter.new( sock )

			### Create the event stream, add the new filters to the stream
			ios = IOEventStream.new
			ios.debugLevel = 5
			ios.addFilters( soFilter )

			### Create the login session and add it to our collection
			session = LoginSession.new( @config, ios, sock.addr[2] )
			session.debugLevel = 5
			@loginSessionsMutex.synchronize(Sync::EX) {
				@loginSessions.push session
			}

			return results
		end


		### (PROTECTED) METHOD: _handlePlayerEvent( event )
		### Handle changes to player status
		def _handlePlayerEvent( event )
			player = event.player

			results = []
			@log.debug( "In _handlePlayerEvent. Event is: #{event.to_s}" )

			### Handle the player status change events by changing the contents of the players hash
			case event

			when PlayerLoginEvent
				stream = event.stream

				### If the player object is already active (ie., already
				### connected and has a shell), remove the old socket connection
				### and re-connect with the new one. Otherwise, just activate
				### the player object.
				if player.activated?
					results << LogEvent.new( "notice", "Player #{player.to_s} reconnected." )
					results << player.reconnect( stream )
				else
					results << LogEvent.new( "notice", "Login succeeded for #{player.to_s}." )
					results << player.activate( stream )
				end

				@playersMutex.synchronize(Sync::EX) {
					@players[ player ] = { "status" => "active" }
				}

			when PlayerDisconnectEvent
				results << LogEvent.new("notice", "Player #{player.name} went link-dead.")
				@playersMutex.synchronize(Sync::EX) { @players[ player ]["status"] = "linkdead" }
				results << player.disconnect

			when PlayerIdleTimeoutEvent
				results << LogEvent.new("notice", "Player #{player.name} disconnected due to idle timeout.")
				# @playersMutex.synchronize {	@players[ player ]["status"] = "linkdead" }
				@playersMutex.synchronize(Sync::EX) { @players.delete( player ) }
				player.disconnect

			when PlayerLogoutEvent
				results << LogEvent.new("notice", "Player #{player.to_s} disconnected.")
				@playersMutex.synchronize(Sync::EX) { @players.delete( player ) }
				player.disconnect

			when PlayerSaveEvent
				@log.debug( "In PlayerSaveEvent handler for #{player.to_s}" )
				results << LogEvent.new("info", "Saving record for player #{player.to_s}.")
				begin
					@engineObjectStore.storePlayer( player )
				rescue Exception => e
					@log.debug( "Error while saving #{player.to_s}: ", e.backtrace.join("\n") )
					results << LogEvent.new("error", "Exception while storing player record for #{player.to_s}")
					### :TODO: Perhaps dump to a rescue file or something?
				end

			else
				_handleUnknownEvent( event )
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
			player = nil

			results = []
			results << LogEvent.new( "info", "Authentication event from session %s for %s@%s" % [
											session.id,
											username,
											remoteHost ])

			### :TODO: Check player bans

			### Look for a player with the same name as the one logging in...
			@playersMutex.synchronize(Sync::SH) {
				player = @players.keys.find {|p| p.username == username }
			}
			player ||= @engineObjectStore.fetchPlayer( username )

			### Fail if no player was found by the name specified...
			if player.nil?
				results << LogEvent.new( "notice", "Authentication failed for user '#{username}': No such user." )
				results << event.failureCallback.call( "No such user" )

			### ...or if the passwords don't match
			elsif player.cryptedPass != MD5.new( event.password ).hexdigest
				results << LogEvent.new( "notice", "Authentication failed for user '#{username}': Bad password." )
				results << event.failureCallback.call( "Bad password" )

			### Otherwise succeed
			else
				results << LogEvent.new( "notice", "User '#{username}' authenticated successfully." )
				player.remoteIp = remoteHost
				results << event.successCallback.call( player )
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
				@loginSessions -= session
			}

			return [ logEvent ]
		end


		### (PROTECTED) METHOD: _handleUntrappedExceptionEvent( event )
		### Handle untrapped exceptions.
		def _handleUntrappedExceptionEvent( event )
			maxSize = @config["engine"]["exceptionStackSize"]
			
			@exceptionStackMutex.synchronize(Sync::EX) {
				@exceptionStack.push event.exception
				while @exceptionStack.length > maxSize
					@exceptionStack.delete_at( maxSize )
				end
			}
			
			[ LogEvent.new( "error", "Untrapped exception: ",
						   event.exception.to_s, "\n\t", 
						   event.exception.backtrace.join("\n\t") ) ]
		end


		### (PROTECTED) METHOD: _handleUntrappedSignalEvent( event )
		### Handle untrapped signals.
		def _handleUntrappedSignalEvent( event )
			if event.exception.is_a?( Interrupt ) then
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
			@log.debug( "Handling a log event (#{event.severity}: #{event.message})." )
			@log.send( event.severity, event.message )
			return []
		end


		### (PROTECTED) METHOD: _handleUnknownEvent( event )
		### Handle events which we get sent for which we don't have an explicit handler
		def _handleUnknownEvent( event )
			@log.error( "Engine received unhandled event type '#{event.class.name}'." )
			return []
		end

	end # class Engine
end # module MUES


