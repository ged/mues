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

* Load, configure, and maintain one or more World objects, which contain a
  class library made up of metaclasses stored in a database

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

--- MUES::Engine#registerHandlerForEvents( handlerObject, *eventClasses )

    Register ((|handlerObject|)) to receive events of the specified
    ((|eventClasses|)) or any of their derivatives. See the docs for MUES::Event
    for how to handle events.

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

module MUES

	### MUES Engine (server) class
	class Engine < Object

		private

		### State constants
		module State
			STOPPED		= 0
			STARTING	= 1
			RUNNING		= 2
			SHUTDOWN	= 3
		end

		include Event::Handler

		### Default constants
		Version			= %q$Revision: 1.4 $
		RcsId			= %q$Id: engine.rb,v 1.4 2001/03/28 22:23:05 deveiant Exp $
		DefaultHost		= 'localhost'
		DefaultPort		= 6565
		DefaultName		= 'ExperimentalMUES'
		DefaultAdmin	= 'MUES Admin <mues@localhost>'

		### Class variables
		@@Instance		= nil

		### Make the new method private, as this class is a singleton
		private_class_method :new

		### (PROTECTED) METHOD: initialize
		protected
		def initialize
			@config = nil
			@log = nil
			@listener = nil
			@listenerThread = nil
			@hostname = DefaultHost
			@port = DefaultPort
			@name = DefaultName
			@admin = DefaultAdmin
			@eventQueue = nil
			@players = {}
			@playersMutex = Mutex.new
			@exceptionStack = []
			@exceptionStackMutex = Mutex.new
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
		attr_reader :hostname, :port, :name, :log, :players, :state

		### (STATIC) METHOD: instance( )
		def Engine.instance

			### :TODO: Put access-checking here to prevent any old thing from getting the instance

			@@Instance = new() if ! @@Instance
			@@Instance
		end


		### METHOD: start( aConfig )
		### Start the server using the specified configuration
		def start( config )
			checkType( config, Config )

			@state = State::STARTING
			@config = config

			### Change working directory to that specified by the config file
			Dir.chdir( @config["rootdir"] )
			
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
									  PlayerEvent
									 )
			
			### :TODO: Register other event handlers

			### Start the event queue
			@log.info( "Starting event queue." )
			@eventQueue = EventQueue.new( @config["eventqueue"]["minworkers"], 
										 @config["eventqueue"]["maxworkers"],
										 @config["eventqueue"]["threshold"] )
			# @eventQueue.debugLevel = true
			@eventQueue.start
			
			### Set up a listener socket on the specified port
			@listener = _setupListenerSocket( @config["engine"]["bindaddress"], 
											 @config["engine"]["bindport"],
											 @config["engine"]["tcpwrapper"] )
			@log.info( "Starting listener thread." )
			@listenerThread = Thread.new { _listenerThreadRoutine }
			@listenerThread.abort_on_exception = true

			# Reset the state to indicate we're running
			@state = State::RUNNING
			@startTime = Time.now

			### Start the event loop
			@log.info( "Starting event loop." )
			_mainThreadRoutine()
			@log.info( "Back from event loop." )

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
			@log.notice( "Stopping engine" )
			@state = State::SHUTDOWN

			### Shut down the listener socket
			@listenerThread.raise( Shutdown )
			@listener.close

			### Disconnect all players
			### :TODO: This should be more graceful, perhaps using PlayerLogoutEvents?
			@playersMutex.synchronize {
				@players.each_key do |player|
					player.disconnect
				end
			}

			### Shut down the event queue
			@log.info( "Shutting down and cleaning up event queue" )
			@eventQueue.shutdown

			### :TODO: Needs more shutdown stuff
		end


		### METHOD: registerHandlerForEvents( anObject, *eventClasses )
		def registerHandlerForEvents( handlerObject, *eventClasses )
			checkResponse( handlerObject, "handleEvent" )

			eventClasses.each do |eventClass|
				eventClass.RegisterHandlers( handlerObject )
			end
		end


		### METHOD: dispatchEvents( *events )
		def dispatchEvents( *events )
			@log.debug( "Dispatching #{events.length} events." )
			@eventQueue.enqueue( events )
		end


		### METHOD: statusString
		### Return a multi-line string indicating the current status of the engine
		def statusString
			status =	"#{@name}\n"
			status +=	" MUES Engine %s\n" % [ Version ]
			status +=	" Up %.2f seconds at tick %s " % [ Time.now - @startTime, @tick ]
			status +=	" %d players logged in, %d linkdead, and %d connecting\n\n" % 
				[ @players.values.find_all {|st| st["status"] == "active"}.size,
				@players.values.find_all {|st| st["status"] == "linkdead"}.size,
				@players.values.find_all {|st| st["status"] == "connecting"}.size ]
			status +=	"\n Players:\n"
			@players.keys.each {|player|
				status += "  #{player.to_s}\n"
			}

			status += "\n"
			return status
		end


		### Protected methods
		protected

		#######################################################################
		###	T H R E A D   R O U T I N E S
		#######################################################################

		### (PROTECTED) METHOD: _mainThreadRoutine()
		### The main event loop. This is the routine that the main thread runs,
		### dispatching TickEvents for timing. Exits and returns the total
		### number of ticks to the caller after stop() is called.
		def _mainThreadRoutine

			@tick = 0

			### Start the event loop until the engine stops running
			dispatchEvents( LogEvent.new("notice", "Starting event loop.") )
			while running? do
				begin
					@tick += 1
					@log.debug( "In tick #{@tick}..." )
					sleep @config["engine"]["TickLength"].to_i
					dispatchEvents( TickEvent.new(@tick) )
				rescue StandardError => e
					dispatchEvents( UntrappedExceptionEvent.new(e) )
					next
				rescue Interrupt, SignalException => e
					dispatchEvents( UntrappedSignalEvent.new(e) )
				end
			end
			dispatchEvents( LogEvent.new("notice", "Exiting event loop.") )

			return @tick
		end


		### (PROTECTED) METHOD: _listenerThreadRoutine()
		### The routine executed by the thread associated with the listen socket
		def _listenerThreadRoutine
			sleep 1 until running?
			dispatchEvents( LogEvent.new("notice", "Accepting connections on #{@listener.addr[2]} port #{@listener.addr[1]}.") )

			### :TODO: Fix race condition: If a connection comes in after stop()
			### has been called, but before the Shutdown exception has been
			### dispatched.
			while running? do
				begin
					playerSock = @listener.accept
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

			@log.notice( "Listener thread exiting." )
		end


		### (PROTECTED) METHOD: _setupListenerSocket( host, port, tcpWrapperedFlag )
		### Set up and return a listener socket (TCPServer) object on the specified host and port, 
		### optionally wrappered in a TCPWrapper object that uses tcp_wrappers
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


		#######################################################################
		###	E V E N T   H A N D L E R S
		#######################################################################

		### (PROTECTED) METHOD: _handleSocketConnectEvent( event )
		### Handle connections to the listener socket.
		def _handleSocketConnectEvent( event )

			@log.notice( "Socket connect from '#{event.socket.addr[2]}'." )
			### :TODO: Handle bans here

			### Copy the event's socket to dynamic variable
			sock = event.socket
			newPlayer = Player.new( sock.addr[2] )

			### Create the event stream and the player
			ioEventStream = IOEventStream.new
			#ioEventStream.debug( 1 )

			### Create new filters based on what kind of connection it is
			### :TODO: This should check for connection type, and generate new
			### filters accordingly. This of course depends on having the filter
			### classes to do so
			liFilter = LoginProxy.new(@config, newPlayer)
			#liFilter.debug( 1 )
			soFilter = SocketOutputFilter.new(sock, newPlayer)
			#soFilter.debug( 1 )
			shellFilter = CommandShell.new( newPlayer )
			#comFilter.debug( 1 )

			### Add the new filters to the stream, then add the stream to the player
			ioEventStream.addFilters( liFilter, soFilter, shellFilter )
			newPlayer.ioEventStream = ioEventStream

			### Handle plain telnet connections
			@playersMutex.synchronize {
				@players[newPlayer] = { "status" => "connecting", "loginTime" => Time.now }
			}

			return []
		end


		### (PROTECTED) METHOD: _handlePlayerEvent( event )
		### Handle changes to player status
		def _handlePlayerEvent( event )
			player = event.player

			### Handle the player status change events by changing the contents of the players hash
			case event

			when PlayerLoginEvent
				@log.notice( "Player #{player.name} logged in." )
				@playersMutex.synchronize {	@players[ player ]["status"] = "active" }

			when PlayerLoginFailureEvent
				@log.notice( "Failed login attempt by player #{player.name}: #{event.reason}." )

			when PlayerDisconnectEvent
				@log.notice( "Player #{player.name} went link-dead." )
				# :TODO: Once reconnect works: 
				# @playersMutex.synchronize {	@players[ player ]["status"] = "linkdead" }
				@playersMutex.synchronize {	@players.delete( player ) }
				player.disconnect

			when PlayerIdleTimeoutEvent
				@log.notice( "Player #{player.name} disconnected due to idle timeout." )
				# :TODO: Once reconnect works: 
				# @playersMutex.synchronize {	@players[ player ]["status"] = "linkdead" }
				@playersMutex.synchronize {	@players.delete( player ) }
				player.disconnect

			when PlayerLogoutEvent
				@log.notice( "Player #{player.name} disconnected." )
				@playersMutex.synchronize {	@players.delete( player ) }
				player.disconnect

			else
				_handleUnknownEvent( event )
			end

			return []
		end

		### (PROTECTED) METHOD: _handlePlayerAuthenticationEvent( event )
		### Handle a user authentication attempt event
		def _handlePlayerAuthenticationEvent( event )

			if ! passwords.key?( event.username )
				event.failureCallback.call( event.player, "No such user" )

			elsif passwords[event.username] != MD5.new( event.password ).hexdigest
				event.failureCallback.call( event.player, "Bad password" )

			else
				event.successCallback.call( event.player )
			end

		end


		### (PROTECTED) METHOD: _handleUntrappedExceptionEvent( event )
		### Handle untrapped exceptions.
		def _handleUntrappedExceptionEvent( event )
			@exceptionStackMutex.synchronize {
				@exceptionStack.push event.exception
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
				@exceptionStackMutex.synchronize {
					@exceptionStack.push event.exception
				}
				[ LogEvent.new( "error", "Untrapped signal: ",
							   event.exception.to_s, "\n\t", 
							   event.exception.backtrace.join("\n\t") ) ]
			end
		end


		### (PROTECTED) METHOD: _handleReconfigEvent( event )
		### Handle any reconfiguration events by re-reading the config
		### file and then reconnecting the listen socket 
		def _handleReconfigEvent( event )
			@config.reload
			if @config.host != @listener.addr[2] || @config.port != @listener.addr[1] then
				@listenerThread.raise Reload
				@listener = _setupListenerSocket( @config["engine"]["bindaddress"], 
												 @config["engine"]["bindport"],
												 @config["engine"]["tcpwrapper"] )
				@listenerThread = Thread.new { _listenerThreadRoutine }
			end

			return []
		end


		### (PROTECTED) METHOD: _handleSystemEvent( event )
		### Handle any system events that don't have explicit handlers
		def _handleSystemEvent( event )

			case event
			when EngineShutdownEvent
				@log.notice( "Engine shut down by #{event.agent.to_s}." )
				stop()
			else
				@log.notice( "Got a system event (a #{event.class.name}) that it not yet handled." )
			end

			return []
		end

		### (PROTECTED) METHOD: _handleLogEvent( event )
		### Handle logging events by writing their content to the syslog
		def _handleLogEvent( event )
			@log.send( event.severity, event.message )
			return []
		end


		### (PROTECTED) METHOD: _handleUnknownEvent( event )
		### Handle events which we get sent for which we don't have an explicit handler
		def _handleUnknownEvent( event )
			[ LogEvent.new( "error", "Engine received unhandled event type '#{event.class.name}'." ) ]
		end

	end # class Engine

end


