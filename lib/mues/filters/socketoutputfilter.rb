#!/usr/bin/ruby
###########################################################################
=begin

=SocketOutputFilter.rb

== Name

SocketOutputFilter - An IP socket output filter class

== Synopsis

  

== Description



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/Debugging"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

require "thread"

module MUES
	class SocketOutputFilter < IOEventFilter
		include Debuggable

		module State
			DISCONNECTED = 0
			CONNECTED = 1
		end
		
		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: socketoutputfilter.rb,v 1.1 2001/03/29 02:34:27 deveiant Exp $

		### How much data to attempt to send at each write, the number of
		### seconds to wait in select(), and the default sort position in the
		### stream
		@@MTU = 4096
		@@SelectTimeout = 0.75
		@@DefaultSortPosition = 100

		### Public methods
		public

		# Accessors
		attr_reader :socket, :readBuffer, :writeBuffer

		### METHOD: initialize( socket )
		### Initialize the filter
		def initialize( aSocket, aPlayer )
			super()
			@writeBuffer = ''
			@writeMutex = Mutex.new
			@state = State::DISCONNECTED
			@player = aPlayer

			@socketThread = Thread.new { __doSocketIO(aSocket) }
		end


		### handleOutputEvents( *events )
		### Handle an output event by appending its data to the output buffer
		def handleOutputEvents( *events )
			events = super( events )
			events.flatten!

			_debugMsg( 1, "Handling #{events.size} output events." )

			# If we're not in a connected state, just return the array we're given
			return events unless @state == State::CONNECTED

			# Lock the output event queue and add the events we've been given to it
			_debugMsg( 1, "Appending '" + events.collect {|e| e.data }.join("") + "' to the output buffer." )
			@writeMutex.synchronize {
				@writeBuffer.concat events.collect {|e| e.data }.join("")
			}

			# We're snarfing up all outbound events, so just return an empty array
			return []
		end


		### METHOD: shutdown
		def shutdown
			@state = State::DISCONNECTED
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
			_debugMsg( 1, "In socket IO thread." )
			mySocket = socket
			buffer = ''
			@state = State::CONNECTED

			### Multiplex I/O, catching IO exceptions
			begin
				readable = []
				writeable = []

				### Loop until we break or get shut down
				until @state == State::DISCONNECTED do
					readable, writable = select( [mySocket], [mySocket], nil, @@SelectTimeout )

					### Read any input from the socket if it's ready
					if ( readable.size > 0 ) then
						buffer += mySocket.sysread( @@MTU )
						_debugMsg( 1, "Read data in select loop (buffer = '#{buffer}', length = #{buffer.length})." )
					end

					### Write any buffered output to the socket if we have output pending
					if ( writable.size > 0 && @writeBuffer.length > 0 ) then
						_debugMsg( 1, "Writing in select loop (writebuffer = '#{@writeBuffer}')." )
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
							_debugMsg( 1, "Read a line: '#{s}' (#{s.length} bytes)." )
							if ( s =~ /\w/ ) then
								_debugMsg( 1, "Creating an input event for input = '#{s.strip}'" )
								newInputEvents.push( InputEvent.new("#{s.strip}") )
							end
							
							""
						}
						queueInputEvents( *newInputEvents )
					end

				end

				### Handle EOF on the socket by dispatching a PlayerDisconnectEvent
			rescue EOFError => e
				@state = State::DISCONNECTED
				engine().dispatchEvents( PlayerDisconnectEvent.new(@player) )

			rescue Shutdown
				mySocket.syswrite( "\n\n>>> Server shutdown <<<\n\n" )

				### Just log any other caught exceptions (for now)
			rescue StandardError => e
				_debugMsg( 1, "EXCEPTION: ", e )
				engine().dispatchEvents( LogEvent.new("error","Error in SocketOutputFilter socket IO routine: #{e.message}") )

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
 
	end # class SocketOutputFilter
end # module MUES


