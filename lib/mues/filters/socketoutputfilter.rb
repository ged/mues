#!/usr/bin/ruby
# 
# This file contains the MUES::SocketOutputFilter class, which is a filter for
# MUES::IOEventStream objects. Instances of this class are participants in an
# IOEventStream chain of responsibility, sending output and reading input from a
# TCPSocket.
# 
# == Synopsis
# 
#   sock = listener.accept
#   sofilter = MUES::SocketOutputFilter.new( sock )
# 
# == Rcsid
# 
# $Id: socketoutputfilter.rb,v 1.9 2002/04/01 16:27:29 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "thread"
require "sync"

require "mues"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

module MUES

	### A derivative of MUES::IOEventFilter that collects input from and sends
	### output to a TCPSocket.
	class SocketOutputFilter < IOEventFilter ; implements MUES::Debuggable

		### A container module for MUES::SocketOutputFilter state contants.
		module State
			DISCONNECTED = 0
			CONNECTED = 1
		end

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.9 $ )[1]
		Rcsid = %q$Id: socketoutputfilter.rb,v 1.9 2002/04/01 16:27:29 deveiant Exp $
		DefaultSortPosition = 300
		DefaultWindowSize = { 'height' => 23, 'width' => 80 }

		# Legibility constants
		NULL = "\000"
		CR   = "\015"
		LF   = "\012"
		EOL  = CR + LF

		### Class attributes

		# Maximum transmissable unit (chunk size)
		@@MTU = 4096

		# Number of seconds to use as a timeout in the select loop
		@@SelectTimeout = 0.1


		### Create and return a new socket output filter with the specified
		### TCPSocket and an optional sort order.
		def initialize( aSocket, order=DefaultSortPosition )
			checkType( aSocket, IPSocket )
			super( order )

			@readBuffer = ''
			@writeBuffer = ''
			@writeMutex = Sync.new
			@state = State::DISCONNECTED
			@remoteHost = aSocket.peeraddr[2]

			@windowSize = DefaultWindowSize.dup

			@socketThread = Thread.new { _ioThreadRoutine(aSocket) }
			@socketThread.desc = "SocketOutputFilter IO thread [fd: #{aSocket.fileno}, peer: #{@remoteHost}]"
		end


		######
		public
		######

		# The read buffer for the filtered socket
		attr_reader :readBuffer

		# The write buffer for the filtered socket
		attr_reader :writeBuffer

		# The name or IP of the remote host
		attr_reader :remoteHost

		# A hash describing the client's window size (<tt>'height'</tt> and
		# <tt>'width'</tt> keys, Fixnum values).
		attr_reader :windowSize


		### Handle the specified output <tt>events</tt> by appending their data
		### to the output buffer.
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


		### Append a string directly onto the output buffer with a
		### line-ending. Useful when doing direct output and flush.
		def puts( aString )
			@writeMutex.synchronize(Sync::EX) {
				@writeBuffer << aString + "\n"
			}
		end

		### Append a string directly onto the output buffer without a line
		### ending. Useful when doing direct output and flush.
		def write( aString )
			@writeMutex.synchronize(Sync::EX) {
				@writeBuffer << aString
			}
		end

		### Shut the filter down, disconnecting from the remote host.
		def stop( streamObject )
			@state = State::DISCONNECTED
			@socketThread.raise Shutdown
			super( streamObject )
		end


		#########
		protected
		#########

		### Thread routine for socket IO multiplexing. Reads data from queued
		### output events, sends it to the remote client, and creates new input
		### events from user input via the specified <tt>socket</tt>.
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

		
		### Send a shutdown message to the client using unbuffered I/O on the
		### <tt>rawSocket</tt> specified, as we won't be around to fetch it from
		### the buffer.
		def _sendShutdownMessage( mySocket )
			mySocket.syswrite( @writeBuffer )
			mySocket.syswrite( "\n>>> Disconnecting <<<\n\n" )
		end


		### Multiplex reading and writing from the given <tt>socket</tt> object, 
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


		### Handle the given raw input <tt>data</tt> which has just been read
		### from the client socket.
		def _handleRawInput( data )
			@readBuffer += data
			_debugMsg( 5, "Handling raw input (@readBuffer = '#{@readBuffer}', " +
					  "length = #{@readBuffer.length})." )

			unless @readBuffer.empty?
				_debugMsg( 4, "Read buffer is non-empty. Trying to get input events from it." )
				@readBuffer = _parseInputBuffer( @readBuffer )
			end
		end

		
		### Parse input events from the given raw <tt>inputBuffer</tt> and
		### return the (possibly) modified buffer after queueing any input
		### events created.
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


