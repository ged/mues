#!/usr/bin/env ruby
=begin 

= Engine

== NAME

Engine.rb - The server class for the MUES system

== SYNOPSIS

== DESCRIPTION

== METHODS

private methods:
initialize - set the defaults for the object.

public read-only accessors:
hostname - the hostname of the engine???
port - the port to bind to???
name - the name of the engine?
log - the error log?
players - how many players are acceptable?
state - ???

public methods:
instance - singleton object creation method.
start - start the engine
started? - true if the engine has started.
running? - true if the engine is running.
stop - shut the engine/server down.
registerHandlerForEvents - register a handler object for a specific type of event.
dispatchEvents - not sure, could be putting events into the queue?
statusString - returns a multi-line string indicating the current status of the engine.
authenticatePlayer - eventually will check the username/password against existing players.

protected methods:
_eventLoop - the main event loop.
thread routines:
_listenerThreadRoutine - will listen to the socket for a connection.
_setupListenerSocket - set up and return a listener socket (TCPServer) object on the specified host and port,
    optionally wrappered in a TCPWrapper object that uses tcp_wrappers.
_handleSocketConnectEvent - handles connections to the listener socket.
_handlePlayerEven - handles changes to player status.
_handleUntrappedExceptoinEvent - handle any untrapped exceptions.
_handleUntrappedSignalEven - handle any untrapped signals.
_handleReconfigEvent - handle any reconfiguration events by re-reading the config file and then reconnecting the listen socket.
_handleSystemEvent - handle any system events that we don't have explicit handlers for.
_handleLogEven - handles logging events by writing their content to the syslog.
_handleUnknownEvent - Handle events which we get sent for which we don't have an explicit handler.

== AUTHOR

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

require "socket"
require "thread"
require "mues/MUES"
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
			ENGINE_STATE_STOPPED	= 0
			ENGINE_STATE_STARTING	= 1
			ENGINE_STATE_RUNNING	= 2
			ENGINE_STATE_SHUTDOWN	= 3
		end
		include Engine::State
		include Event::Handler

		### Default constants
		Version			= %q$Revision: 1.2 $
		RcsId			= %q$Id: engine.rb,v 1.2 2001/03/21 23:21:36 phaedrus Exp $
		DefaultHost		= 'localhost'
		DefaultPort		= 6565
		DefaultName		= 'ExperimentalMUES'
		DefaultAdmin	= 'MUES Admin <mues@localhost>'

		### Class variables
		@@Instance		= nil

		### Make the new method private, as this class is a singleton
		private_class_method :new

		### (PRIVATE) METHOD: initialize
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
			@state = ENGINE_STATE_STOPPED
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

			@state = ENGINE_STATE_STARTING
			@config = config

			### Change working directory to that specified by the config file
			Dir.chdir( @config["rootdir"] )
			
			# Set the server name to the one specified by the config
			@name = @config["name"]
			@admin = @config["admin"]

			### Sanity-check the log handle and assign it
			@log = Log.new( @config["rootdir"] + "/" + @config["logfile"] )
			@log.notice( "Engine startup for #{@name} at #{Time.now.to_s}" )

			### Connect to the MUES database
			@log.info( "Creating Engine objectstore: %s %s@%s" % [
						  @config['database']['driver'],
						  @config['database']['db'],
						  @config['database']['host']
					  ])
			@engineObjectStore = ObjectStore.new( @config["database"]["driver"],
												  @config["database"]["db"],
												  @config["database"]["host"],
												  @config["database"]["username"],
												  @config["database"]["password"] )

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
			@state = ENGINE_STATE_RUNNING
			@startTime = Time.now

			### Start the event loop
			@log.info( "Starting event loop." )
			_eventLoop()
			@log.info( "Back from event loop." )

			return true
		end

		### METHOD: started?()
		### Return true if the server is currently started or running
		def started?
			return @state == ENGINE_STATE_STARTING || running?
		end

		### METHOD: running?()
		### Return true if the server is currently running
		def running?
			return @state == ENGINE_STATE_RUNNING
		end

		### METHOD: stop()
		### Shut the server down
		def stop()
			@log.notice( "Stopping engine" )
			@state = ENGINE_STATE_SHUTDOWN

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


		### METHOD: authenticatePlayer( username, password )
		### Return true if the given username + password matches a valid player.
		def authenticatePlayer( username, password )

		end

		###############################################################################
		###	P R O T E C T E D   M E T H O D S
		###############################################################################
		protected

		### The event loop
		def _eventLoop

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

		end


		### Thread routines

		### (PROTECTED) METHOD: _listenerThreadRoutine()
		### The routine executed by the thread associated with the listen socket
		def _listenerThreadRoutine
			sleep 1 until running?
			dispatchEvents( LogEvent.new("notice", "Accepting connections on #{@listener.addr[2]} port #{@listener.addr[1]}.") )

			while running? do
				begin
					playerSock = @listener.accept
					conn = Thread.new {
						dynSock = playerSock
						dispatchEvents( SocketConnectEvent.new(dynSock) )
					}
					conn.join
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

		### Event handlers

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
			liFilter = LoginInputFilter.new(@config, newPlayer)
			#liFilter.debug( 1 )
			soFilter = SocketOutputFilter.new(sock, newPlayer)
			#soFilter.debug( 1 )
			shellFilter = ShellInputFilter.new( newPlayer )
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
			when Player
			else
				_handleUnknownEvent( event )
			end

			return []
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


