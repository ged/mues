#!/usr/bin/ruby
###########################################################################
=begin

=SocketOutputFilter.rb

== Name

SocketOutputFilter - An IP socket output filter class

== Synopsis

  sock = listener.accept
  sofilter = MUES::SocketOutputFilter.new( sock )

== Description

Instances of this class are participants in an IOEventStream chain of
responsibility, sending output and reading input from a TCPSocket.

== Modules
=== MUES::SocketOutputFilter::State

A namespace for type constants. Contains:

: State::CONNECTED

  The filter contains a connected socket.

: State::DISCONNECTED

  The filter does not contain a connected socket.

== Classes
=== MUES::SocketOutputFilter

==== Constructor

--- MUES::SocketOutputFilter.new( socket )

    Initialize the filter with the specified ((|socket|)).

==== Public Methods

--- MUES::SocketOutputFilter#queueOutputEvents( *events )

    Add the data from the specified ((|events|)) to the output buffer for
    transmission.

--- MUES::SocketOutputFilter#readBuffer

    Return the filter^s read buffer.

--- MUES::SocketOutputFilter#writeBuffer

    Return the filter^s write buffer.

--- MUES::SocketOutputFilter#remoteHost

    Return the value of the remoteHost attribute.

--- MUES::SocketOutputFilter#puts( aString )

    Append a string directly onto the output buffer. Useful when doing direct
    output and flush.

--- MUES::SocketOutputFilter#shutdown

    Shut the filter down.

==== Protected Methods

--- MUES::SocketOutputFilter#_ioThreadRoutine( socket )

    Thread routine for socket IO multiplexing. Reads data from queued output
    events and sends it to the remote client, and creates new input events
    from user input.

--- MUES::SocketOutputFilter#_parseInputBuffer( inputBuffer )

    Parse input events from the given raw buffer and return the
    (possibly) modified buffer after queueing any input events created.

--- MUES::SocketOutputFilter#_sendShutdownMessage( rawSocket )

    Send a shutdown message to the client using unbuffered I/O on the
    ((|rawSocket|)) specified, as we won^t be around to fetch it from
    the buffer.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "thread"
require "sync"

require "mues/Namespace"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

module MUES
	class SocketOutputFilter < IOEventFilter ; implements Debuggable

		# State constants
		module State
			DISCONNECTED = 0
			CONNECTED = 1
		end

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.8 $ )[1]
		Rcsid = %q$Id: socketoutputfilter.rb,v 1.8 2001/11/01 17:52:07 deveiant Exp $
		DefaultSortPosition = 300

		NULL = "\000"
		CR   = "\015"
		LF   = "\012"
		EOL  = CR + LF

		### Class attributes
		@@MTU = 4096				# Maximum Transmissable Unit
		@@SelectTimeout = 0.1	# The number of seconds to wait in select()

		### (PROTECTED) METHOD: initialize( socket [, order] )
		### Initialize the filter
		protected
		def initialize( aSocket, order=DefaultSortPosition )
			checkType( aSocket, IPSocket )
			super( order )

			@readBuffer = ''
			@writeBuffer = ''
			@writeMutex = Sync.new
			@state = State::DISCONNECTED
			@remoteHost = aSocket.peeraddr[2]

			@windowSize = { 'height' => 23, 'width' => 80 }

			@socketThread = Thread.new { _ioThreadRoutine(aSocket) }
			@socketThread.desc = "SocketOutputFilter IO thread [fd: #{aSocket.fileno}, peer: #{@remoteHost}]"
		end


		#############################################################
		###	P U B L I C   M E T H O D S
		#############################################################
		public

		# Accessors
		attr_reader :readBuffer, :writeBuffer, :remoteHost, :windowSize

		### METHOD: handleOutputEvents( *events )
		### Handle output events by appending their data to the output buffer
		def handleOutputEvents( *events )
			events = super( *events )
			events.flatten!

			_debugMsg( 1, "Handling #{events.size} output events." )

			# If we're not in a connected state, just return the array we're given
			return events unless @state == State::CONNECTED

			# Lock the output event queue and add the events we've been given to it
			_debugMsg( 1, "Appending '" + events.collect {|e| e.data }.join("") + "' to the output buffer." )
			@writeMutex.synchronize(Sync::EX) {
				@writeBuffer << events.collect {|e| e.data }.join("")
			}

			# We're snarfing up all outbound events, so just return an empty array
			return []
		end


		### METHOD: puts( aString )
		### Append a string directly onto the output buffer with a
		### line-ending. Useful when doing direct output and flush.
		def puts( aString )
			@writeMutex.synchronize(Sync::EX) {
				@writeBuffer << aString + "\n"
			}
		end

		### METHOD: write( aString )
		### Append a string directly onto the output buffer without a line
		### ending. Useful when doing direct output and flush.
		def write( aString )
			@writeMutex.synchronize(Sync::EX) {
				@writeBuffer << aString
			}
		end

		### METHOD: shutdown
		def shutdown
			@state = State::DISCONNECTED
			@socketThread.raise Shutdown
			super
		end


		#############################################################
		###	P R O T E C T E D   M E T H O D S
		#############################################################
		protected

		### (PROTECTED) METHOD: _ioThreadRoutine( socket )
		### Thread routine for socket IO multiplexing. Reads data from queued
		### output events and sends it to the remote client, and creates new
		### input events from user input.
		def _ioThreadRoutine( socket )
			_debugMsg( 1, "In IO thread routine." )
			mySocket = socket
			@state = State::CONNECTED

			### Multiplex I/O, catching IO exceptions
			begin
				_ioLoop( mySocket )

			### Handle EOF on the socket by setting the state and 
			rescue EOFError => e
				engine.dispatchEvents( LogEvent.new("info", "SocketOutputFilter shutting down: #{e.message}") )

			rescue Shutdown
				self._sendShutdownMessage( mySocket )

			### Just log any other caught exceptions (for now)
			rescue StandardError => e
				_debugMsg( 1, "EXCEPTION: ", e )
				engine.dispatchEvents( LogEvent.new("error","Error in SocketOutputFilter socket IO routine: #{e.message}") )

			### Make sure that the handler is set to the disconnected state and
			### clean up the socket when we're leaving
			ensure
				_debugMsg( 1, "In socket IO thread routine's cleanup (#{$@.to_s})." )
				@state = State::DISCONNECTED
				mySocket.flush
				mySocket.shutdown( 2 )
				mySocket.close
			end

		end

		
		### (PROTECTED) METHOD: _sendShutdownMessage( rawSocket )
		### Send a shutdown message to the client using unbuffered I/O on the
		### ((|rawSocket|)) specified, as we won't be around to fetch it from
		### the buffer.
		def _sendShutdownMessage( mySocket )
			mySocket.syswrite( @writeBuffer )
			mySocket.syswrite( "\n>>> Disconnecting <<<\n\n" )
		end


		### (PROTECTED) METHOD: _ioLoop( socket )
		### Multiplex reading and writing from the given ((|socket|)) object, 
		def _ioLoop( mySocket )
			readable = [mySocket]
			writable = []
			errors = [mySocket]

			### Loop until we break or get shut down
			loop do

				# The socket only goes into the writable array if there's
				# something to write.
				if @writeBuffer.empty?
					writable -= [ mySocket ]
				else
					writable += [ mySocket ]
				end

				# Select on the socket
				rsock, wsock, esock = select( readable, writable, errors, @@SelectTimeout )
				_debugMsg( 5, "Readable: %s, writable: %s, errors: %s" % [
							  rsock.nil? ? "(nil)" : rsock.length.to_s,
							  wsock.nil? ? "(nil)" : wsock.length.to_s,
							  esock.nil? ? "(nil)" : esock.length.to_s
						  ])

				# If all three arrays are empty or nil, pass execution to another thread
				if (rsock.nil?||rsock.empty?) && (wsock.nil?||wsock.empty?) && (esock.nil?||esock.empty?)
					Thread.pass
					
				else

					### Handle socket errors
					if !esock.nil? && esock.length.nonzero?
						so_error = mySocket.getsockopt( SOL_SOCKET, SO_ERROR )
						_debugMsg( 2, "Socket error: #{so_error.inspect}" )
					end

					### Read any input from the socket if it's ready
					if !rsock.nil? && rsock.length.nonzero?
						readData = mySocket.sysread( @@MTU )
						_debugMsg( 5, "Read data in select loop (readData = '#{readData}', length = #{readData.length})." )
						_handleRawInput( readData )
					end

					### Write any buffered output to the socket if we have
					### output pending and the socket is writable
					if !wsock.nil? && wsock.length.nonzero?
						_debugMsg( 5, "Writing in select loop (@writebuffer = '#{@writeBuffer}')." )
						@writeMutex.synchronize(Sync::EX) {
							bytesWritten = mySocket.syswrite( @writeBuffer )
							@writeBuffer[0 .. bytesWritten] = ''
						}
					end
				end
			end
		end


		### TODO: Possibly abstract the output buffer handling away from the
		### ioLoop, too?


		### (PROTECTED) METHOD: _handleRawInput( data )
		### Handle the given raw input data which has just been read from the
		### client socket.
		def _handleRawInput( data )
			@readBuffer += data
			_debugMsg( 5, "Handling raw input (@readBuffer = '#{@readBuffer}', " +
					  "length = #{@readBuffer.length})." )

			unless @readBuffer.empty?
				_debugMsg( 4, "Read buffer is non-empty. Trying to get input events from it." )
				@readBuffer = _parseInputBuffer( @readBuffer )
			end
		end

		
		### (PROTECTED) METHOD: _parseInputBuffer( inputBuffer )
		### Parse input events from the given raw buffer and return the
		### (possibly) modified buffer after queueing any input events created.
		def _parseInputBuffer( inputBuffer )
			newInputEvents = []

			# Split input lines by CR+LF and strip whitespace before
			# creating an event
			inputBuffer.gsub!( /^([^#{CR}#{LF}]*)#{CR}#{LF}?/ ) {|s|
				_debugMsg( 5, "Read a line: '#{s}' (#{s.length} bytes)." )

					_debugMsg( 4, "Creating an input event for input = '#{s.strip}'" )
					newInputEvents.push( InputEvent.new("#{s.strip}") )
				
				""
			}

			queueInputEvents( *newInputEvents )
			return inputBuffer
		end
 
	end # class SocketOutputFilter
end # module MUES


