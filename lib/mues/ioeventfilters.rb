#!/usr/bin/ruby
###########################################################################
=begin
= IOEventFilters.rb
== Name

MUES::IOEventFilters - Filter classes for MUES::IOEventStream objects.

== Synopsis

  require "mues/IOEventFilters"
  require "mues/IOEventStream"
  require "mues/Events"

  stream = MUES::IOEventStream.new
  soFilter = MUES::SocketOutputFilter( aSocket )
  shFilter = MUES::ShellInputFilter( aPlayerObject )
  snFilter = MUES::SnoopFilter( anIOEventStream )

  stream.addFilters( soFilter, shFilter, snFilter )

== Description

This is an abstract base class for input and output event filters. Instances of
derivatives of this class act as filters for an IOEventStream object in
interactive components of the FaerieMUD Engine. They can be used to filter or
channel input from the user and output from Engine subsystems or the user^s
player object.

See the documentation for IOEventStream for an example usage of derivatives of
this class.

== Author

Michael Granger E<lt>ged@FaerieMUD.orgE<gt>

Copyright (c) 2000, The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

###########################################################################

require "mues/MUES"
require "mues/Debugging"
require "mues/Events"
require "mues/Exceptions"
require "thread"

module MUES

	###############################################################################
	###	I O   E V E N T   F I L T E R   A B S T R A C T   B A S E   C L A S S
	###############################################################################
	### (ABSTRACT BASE) CLASS: IOEventFilter < Object
	### An abstract base for IO Event Filter classes.
	class IOEventFilter < Object
		include Comparable
		include Debuggable
		include AbstractClass

		### Filters must be registered here to be used without setting an explicit
		### sort disposition
		@@FilterRegistry = %w{
			DefaultOutputFilter
			SocketOutputFilter
			ClientOutputFilter
			MacroFilter
			SnoopFilter
			LoginInputFilter
			ShellInputFilter
			CommandInputFilter
			DefaultInputFilter
		}

		### Public methods
		public

		attr_accessor	:sortDisposition
		attr_reader		:queuedInputEvents, :queuedOutputEvents, :isFinished

		### (STATIC) METHOD: GetDefaultSortDisposition( classOrObject )
		###	Return an integer which represents the default sort order of the given
		###		class or filter object in the filter registry. Returns nil if the
		###		specified class doesn't exist in the registry
		def IOEventFilter.GetDefaultSortDisposition( aClassOrObject )
			checkType( aClassOrObject, Class, IOEventFilter )
			indexClass = if aClassOrObject.class.is_a?( Class ) then
							 aClassOrObject
						 else
							 aClassOrObject.class
						 end

			rv = @@FilterRegistry.index( indexClass.name )
			raise RuntimeError, "The #{indexClass.name} class isn't registered in the filter registry." unless rv
			return rv
		end

		### METHOD: initialize
		### Initialize the filter
		def initialize( order=nil )
			if order.nil?
				@sortDisposition = IOEventFilter.GetDefaultSortDisposition( self.class )
			else
				@sortDisposition = order
			end

			@queuedInputEvents = []
			@queuedInputEventsMutex = Mutex.new
			@queuedOutputEvents = []
			@queuedOutputEventsMutex = Mutex.new

			@isFinished = false

			super()
		end

		### METHOD: shutdown
		### Shut the filter down
		def shutdown
			@isFinished = true
			return @queuedInputEvents + @queuedOutputEvents
		end

		### METHOD: queueInputEvents( *events )
		### Add saved input events for this filter that will be injected into the
		### event stream on the next IO loop.
		def queueInputEvents( *events )
			events.flatten!
			checkEachType( events, InputEvent )

			_debugMsg( "Queueing #{events.size} input events." )
			@queuedInputEventsMutex.synchronize {
				@queuedInputEvents += events
			}
			_debugMsg( "#{@queuedInputEvents.size} input events now queued." )

			return @queuedInputEvents.size
		end

		### METHOD: queueOutputEvents( *events )
		### Add saved output events for this filter that will be injected into the
		### event stream on the next IO loop.
		def queueOutputEvents( *events )
			events.flatten!
			checkEachType( events, OutputEvent )

			@queuedOutputEventsMutex.synchronize {
				@queuedOutputEvents += events
			}
			_debugMsg( "#{@queuedOutputEvents.size} output events now queued." )

			return @queuedOutputEvents.size
		end

		### (OPERATOR) METHOD: <=>( anIOEventFilterObject )
		### Comparison -- Returns -1, 0, or 1 if the receiver sorts higher, equal
		### to, or lower than the specified object, respectively.
		def <=>( anObject )
			checkType( anObject, IOEventFilter )
			return self.sortDisposition <=> anObject.sortDisposition
		end

		### (VIRTUAL) METHOD: handleInputEvents( *events )
		### Default filter method for input events
		def handleInputEvents( *events )
			@queuedInputEventsMutex.synchronize {
				events += @queuedInputEvents
				@queuedInputEvents.clear
			}
			return events.flatten
		end

		### (VIRTUAL) METHOD: handleOutputEvents( *events )
		### Default filter method for output events
		def handleOutputEvents( *events )
			events.flatten!
			_debugMsg( "There are #{@queuedOutputEvents.size} output events queued, and I've been given #{events.size}." )

			@queuedOutputEventsMutex.synchronize {
				events += @queuedOutputEvents
				@queuedOutputEvents.clear
			}
			return events.flatten
		end

	end


	###############################################################################
	###	D E F A U L T   O U T P U T   F I L T E R   C L A S S
	###############################################################################
	### CLASS: DefaultOutputFilter
	### The default output handler object class (stores history for any output)
	class DefaultOutputFilter < IOEventFilter

		attr_accessor :history

		### METHOD: initialize()
		def initialize
			super()
			@history = []
		end

		### METHOD: handleOutputEvents( *events )
		def handleOutputEvents( *events )

			### Add event data to history
			@history = [] unless @history.is_a?( Array )
			@history += events.flatten.collect{|event| event.data}
			@history = @history[-10..-1]
			[]
		end

	end



	###############################################################################
	###	S O C K E T   O U T P U T   F I L T E R   C L A S S
	###############################################################################
	### CLASS: SocketOutputFilter
	class SocketOutputFilter < IOEventFilter

		module States
			DISCONNECTED = 0
			CONNECTED = 1
		end
		include SocketOutputFilter::States
		include Debuggable
		
		attr_reader :socket, :readBuffer, :writeBuffer

		### How much data to attempt to send at each write, and the number of seconds 
		### to wait in select()
		@@MTU = 4096
		@@SelectTimeout = 0.75

		### Public methods
		public

		### METHOD: initialize( socket )
		### Initialize the filter
		def initialize( aSocket, aPlayer )
			super()
			@writeBuffer = ''
			@writeMutex = Mutex.new
			@state = DISCONNECTED
			@player = aPlayer

			@socketThread = Thread.new { __doSocketIO(aSocket) }
		end


		### handleOutputEvents( *events )
		### Handle an output event by appending its data to the output buffer
		def handleOutputEvents( *events )
			events = super( events )
			events.flatten!

			_debugMsg( "Handling #{events.size} output events." )

			# If we're not in a connected state, just return the array we're given
			return events unless @state == CONNECTED

			# Lock the output event queue and add the events we've been given to it
			_debugMsg( "Appending '" + events.collect {|e| e.data }.join("") + "' to the output buffer." )
			@writeMutex.synchronize {
				@writeBuffer.concat events.collect {|e| e.data }.join("")
			}

			# We're snarfing up all outbound events, so just return an empty array
			return []
		end


		### METHOD: shutdown
		def shutdown
			@state = DISCONNECTED
			@socketThread.raise Shutdown
			super
		end

		### Private methods
		private

		### (PRIVATE) METHOD: __doSocketIO( socket )
		###	Thread routine for socket IO multiplexing. Reads data from queued output
		###		events and sends it to the remote client, and creates new input events
		###		from user input.
		def __doSocketIO( socket )
			_debugMsg( "In socket IO thread." )
			mySocket = socket
			buffer = ''
			@state = CONNECTED

			### Multiplex I/O, catching IO exceptions
			begin
				readable = []
				writeable = []

				### Loop until we break or get shut down
				until @state == DISCONNECTED do
					readable, writable = select( [mySocket], [mySocket], nil, @@SelectTimeout )

					### Read any input from the socket if it's ready
					if ( readable.size > 0 ) then
						buffer += mySocket.sysread( @@MTU )
						_debugMsg( "Read data in select loop (buffer = '#{buffer}', length = #{buffer.length})." )
					end

					### Write any buffered output to the socket if we have output pending
					if ( writable.size > 0 && @writeBuffer.length > 0 ) then
						_debugMsg( "Writing in select loop (writebuffer = '#{@writeBuffer}')." )
						@writeMutex.synchronize {
							bytesWritten = mySocket.syswrite( @writeBuffer )
							@writeBuffer[0 .. bytesWritten] = ''
						}
					end

					### Create any input events that are parseable from the buffer
					### and queue them for the next input pass
					if buffer.length > 0 then
						newInputEvents = []
						buffer.gsub!( /^([^\n\r]*)\r\n?/ ) {|s|
							_debugMsg( "Read a line: '#{s}' (#{s.length} bytes)." )
							if ( s =~ /\w/ ) then
								_debugMsg( "Creating an input event for input = '#{s.strip}'" )
								newInputEvents.push( InputEvent.new("#{s.strip}") )
							end
							
							""
						}
						queueInputEvents( *newInputEvents )
					end

				end

				### Handle EOF on the socket by dispatching a PlayerDisconnectEvent
			rescue EOFError => e
				@state = DISCONNECTED
				Engine.instance.dispatchEvents( PlayerDisconnectEvent.new(@player) )

			rescue Shutdown
				mySocket.syswrite( "\n\n>>> Server shutdown <<<\n\n" )

				### Just log any other caught exceptions (for now)
			rescue StandardError => e
				_debugMsg( "EXCEPTION: ", e )
				Engine.instance.dispatchEvents( LogEvent.new("error","Error in SocketOutputFilter socket IO routine: #{e.message}") )

				### Make sure that the handler is set to the disconnected state and
				### clean up the socket when we're leaving
			ensure
				_debugMsg( "In socket IO thread routine's cleanup (#{$@.to_s})." )
				@state = DISCONNECTED
				mySocket.flush
				mySocket.shutdown( 2 )
				mySocket.close
			end

		end
	end


	### CLASS: ClientOutputFilter
	### Filter class for the player client
	class ClientOutputFilter < IOEventFilter
	end


	### CLASS: MacroFilter
	### User-defined macro filter class
	class MacroFilter < IOEventFilter
	end


	### CLASS: SnoopFilter
	### IO snooping filter class
	class SnoopFilter < IOEventFilter
	end


	### CLASS: LoginInputFilter
	### Authentication filter class
	class LoginInputFilter < IOEventFilter
		include Debuggable
		
		### :TODO: Testing code only
		@@Logins = { 
			"ged"	=> { "password" => "testing", "isImmortal" => true },
			"guest" => { "password" => "guest", "isImmortal" => false },
		}

		attr_accessor :cachedInput, :cachedOutput, :initTime, :player, :login

		### METHOD: initialize( aConfig )
		### Initialize a new login input filter object
		def initialize( aConfig, aPlayer )
			unless $0 == __FILE__ then
				checkType( aConfig, Config )
				checkType( aPlayer, Player )

				@config				= aConfig
				@player				= aPlayer
				@cachedInput		= []
				@cachedInputMutex	= Mutex.new
				@cachedOutput		= []
				@cachedOutputMutex	= Mutex.new
				@initTime			= Time.now
				@tries				= 0
				@login				= nil

				super()
				self.queueOutputEvents( OutputEvent.new(@config["login"]["banner"]),
									   OutputEvent.new(@config["login"]["userprompt"]) )
			else
				super()
			end
		end
		
		### METHOD: handleInputEvents( *events )
		### Handle all input until the user has satisfied login requirements, then
		### pass all input to upstream handlers.
		### :TODO: Most of this stuff will need to be modified to access the player
		### database once that's working.
		def handleInputEvents( *events )
			if @isFinished then
				return super( events )
			end

			returnEvents = []
			_debugMsg( "LoginInputFilter: Handling #{returnEvents.size} input events." )

			### Check to see if login has timed out
			if ( Time.now - @initTime >= @config["login"]["timeout"].to_f ) then
				_debugMsg( "Login has timed out." )
				queueOutputEvents( OutputEvent.new( ">>> Timed out <<<" ) )
				engine.dispatchEvents( PlayerLoginFailureEvent.new(@player, "Timeout.") )
				
			else

				### Iterate over each input event, checking username/password
				events.flatten.each do |event|

					_debugMsg( "Processing input event '#{event.to_s}'" )

					### If we're finished logging in, add any remaining events to
					### the cached input events
					if @isFinished then
						returnEvents.push( event )
						next
					end

					### If the login hasn't been set yet, fill it in and move on to the next
					if ! @login then
						_debugMsg( "Setting login to '#{event.data}'." )
						@login = event.data
						queueOutputEvents( OutputEvent.new(@config["login"]["passprompt"]) )

						### If there's a player by the name specified, and the password
						### matches, then log the player in
					elsif _authenticateUser( @login, event.data ) then
						_debugMsg( "Player authenticated successfully." )
						@player.name = @login
						@player.isImmortal = @@Logins[ @login ]["isImmortal"]

						queueOutputEvents( OutputEvent.new("Logged in.\n\n"), OutputEvent.new(@player.prompt) )
						engine.dispatchEvents( PlayerLoginEvent.new(@player) )
						@isFinished = true

						### Otherwise, they failed
					else
						_debugMsg( "Login failed." )
						@tries += 1

						### Only allow a certain number of tries
						if @config["login"]["maxtries"].to_i > 0 && @tries > @config["login"]["MaxTries"].to_i then
							_debugMsg( "Max login tries exceeded." )
							queueOutputEvents( OutputEvent.new(">>> Max tries exceeded. <<<") )
							engine.dispatchEvents( PlayerLoginFailureEvent.new(@player) )
						else
							_debugMsg( "Failed login attempt #{@tries} for user '#{@login}'." )
							logMsg = "Failed login attempt #{@tries} for user '#{@login}'."
							engine.dispatchEvents( LogEvent.new("notice", logMsg) )
							queueOutputEvents( OutputEvent.new(@config["login"]["userprompt"]) )
						end

						@login = nil
					end
				end
			end

			return [ returnEvents ].flatten
		end


		### METHOD: handleOutputEvents( *events )
		### Cache and squelch all output
		def handleOutputEvents( *events )
			events.flatten!
			checkEachType( events, OutputEvent )

			@cachedOutputMutex.synchronize {
				@cachedOutput += events
			}

			_debugMsg( "I have #{@queuedOutputEvents.length} pending output events." )
			ev = super()
			ev.flatten!
			_debugMsg( "Parent class's handleOutputEvents() returned #{ev.size} events." )

			return ev
		end

		### (PROTECTED) METHOD: _authenticatePlayer( login, password )
		protected
		def _authenticatePlayer( login, password )
			return Engine.authenticatePlayer( login, password )
		end

	end


	### CLASS: ShellInputFilter
	### Player shell input filter class
	class ShellInputFilter < IOEventFilter

		### METHOD: initialize( aPlayer )
		### Initialize a new shell input filter
		def initialize( aPlayer )
			super()
			@player = aPlayer
		end

		### METHOD: handleInputEvents( *events )
		### Handle input events by comparing them to the list of valid shell
		### commands and creating the appropriate events for any that do.
		def handleInputEvents( *events )
			unknownCommands = []

			_debugMsg( "Got #{events.size} input events to filter." )

			### :TODO: This is probably only good for a few commands. Eventually,
			### this will probably become a dispatch table which gets shell commands
			### dynamically from somewhere.
			events.flatten.each do |e|

				case e.data
				when /^q(uit)?/
					engine.dispatchEvents( PlayerLogoutEvent.new(@player) )
					break
				when /^shutdown/
					engine.dispatchEvents( EngineShutdownEvent.new(@player) )
					break
				when /^status/
					queueOutputEvents( OutputEvent.new(engine.statusString) )
				else
					unknownCommands.push e
				end

				queueOutputEvents( OutputEvent.new(@player.prompt) )
			end

			return unknownCommands
		end
	end


	### CLASS: CommandInputFilter
	### Character command input filter class
	class CommandInputFilter < IOEventFilter
	end


	### CLASS: DefaultInputFilter
	### Default input filter class (generates errors for any input)
	class DefaultInputFilter < IOEventFilter
		@@ErrorMessages = [ 
			"Huh?", 
			"I'm afraid I don't understand you.", 
			"What exactly am I supposed to do with '%s'?"
		]

		### METHOD: initialize
		def initialize
			super
			@errorIndex = 0
		end

		### METHOD: handleInputEvents( *events )
		def handleInputEvents( *events )
			events.flatten.each do |e|
				Thread.critical = true
				begin
					msg = e.data
					@errorIndex += 1
					@errorIndex = 0 if @errorIndex > @@ErrorMessages.length - 1

					errmsg = @@ErrorMessages[ @errorIndex ] % msg
					queueOutputEvents( OutputEvent.new(errmsg + "\n") )
				ensure
					Thread.critical = false
				end
			end

			return []
		end

	end

end # module MUES

