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
		Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
		Rcsid = %q$Id: socketoutputfilter.rb,v 1.7 2001/09/26 13:30:39 deveiant Exp $
		DefaultSortPosition = 300

		NULL = "\000"
		CR   = "\015"
		LF   = "\012"
		EOL  = CR + LF

		### Class attributes
		@@MTU = 4096				# Maximum Transmissable Unit

		### (PROTECTED) METHOD: initialize( socket )
		### Initialize the filter
		protected
		def initialize( aSocket, order=DefaultSortPosition )
			checkType( aSocket, IPSocket )
			super( order )

			@readBuffer = ''
			@readMutex = Sync.new
			@writeBuffer = ''
			@writeMutex = Sync.new
			@state = State::DISCONNECTED
			@remoteHost = aSocket.peeraddr[2]

			@mode = ''

			@socketThread = Thread.new { _ioThreadRoutine(aSocket) }
			@socketThread.desc = "SocketOutputFilter IO thread [fd: #{aSocket.fileno}, peer: #{@remoteHost}]"
		end


		#############################################################
		###	P U B L I C   M E T H O D S
		#############################################################
		public

		# Accessors
		attr_reader :readBuffer, :writeBuffer, :remoteHost

		### handleOutputEvents( *events )
		### Handle an output event by appending its data to the output buffer
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
		### Append a string directly onto the output buffer. Useful when doing
		### direct output and flush.
		def puts( aString )
			@writeMutex.synchronize(Sync::EX) {
				@writeBuffer << aString + "\n"
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
		###	Thread routine for socket IO multiplexing. Reads data from queued output
		###		events and sends it to the remote client, and creates new input events
		###		from user input.
		def _ioThreadRoutine( socket )
			_debugMsg( 1, "In IO thread routine." )
			mySocket = socket
			@state = State::CONNECTED

			### Multiplex I/O, catching IO exceptions
			begin
				readable = []
				writeable = []

				### Loop until we break or get shut down
				loop do
					readable, writable = select( [mySocket], [mySocket] )

					### Read any input from the socket if it's ready
					unless readable.empty?
						@readMutex.synchronize(Sync::EX) {
							@readBuffer += mySocket.sysread( @@MTU )
							_debugMsg( 5, "Read data in select loop (@readBuffer = '#{@readBuffer}', " +
									   "length = #{@readBuffer.length})." )

							unless @readBuffer.empty?
								_debugMsg( 4, "Read buffer has stuff in it. Trying to get input events from it." )
								@readBuffer = _parseRawInput( @readBuffer )
							end
						}
					end

					### Write any buffered output to the socket if we have
					### output pending and the socket is writable
					unless writable.empty? || @writeBuffer.empty?
						_debugMsg( 5, "Writing in select loop (@writebuffer = '#{@writeBuffer}')." )
						@writeMutex.synchronize(Sync::EX) {
							bytesWritten = mySocket.syswrite( @writeBuffer )
							@writeBuffer[0 .. bytesWritten] = ''
						}
					end
				end

			### Handle EOF on the socket by setting the state and 
			rescue EOFError => e
				engine.dispatchEvents( LogEvent.new("info", "SocketOutputFilter shutting down: #{e.message}") )

			rescue Shutdown
				mySocket.syswrite( @writeBuffer )
				mySocket.syswrite( "\n>>> Disconnecting <<<\n\n" )

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

		
		### (PROTECTED) METHOD: _parseRawInput( inputBuffer )
		### Parse input events from the given raw buffer and return the
		### (possibly) modified buffer after queueing any input events created.
		def _parseRawInput( inputBuffer )
			newInputEvents = []

			# Split input lines by CR+LF and strip whitespace before
			# creating an event
			inputBuffer.gsub!( /^([^#{CR}#{LF}]*)#{CR}#{LF}?/ ) {|s|
				_debugMsg( 5, "Read a line: '#{s}' (#{s.length} bytes)." )

				#if ( s =~ /\w/ )
					_debugMsg( 4, "Creating an input event for input = '#{s.strip}'" )
					newInputEvents.push( InputEvent.new("#{s.strip}") )
				#end
				
				""
			}

			queueInputEvents( *newInputEvents )
			return inputBuffer
		end
 
	end # class SocketOutputFilter
end # module MUES


