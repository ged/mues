#!/usr/bin/ruby
###########################################################################
=begin

=ConsoleOutputFilter.rb

== Name

ConsoleOutputFilter - A console output filter class

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

require "thread"
require "sync"

require "mues/Namespace"
require "mues/Debugging"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

module MUES
	class ConsoleOutputFilter < IOEventFilter
		include Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: consoleoutputfilter.rb,v 1.1 2001/05/14 12:32:17 deveiant Exp $
		DefaultSortPosition = 300

		NULL = "\000"
		CR   = "\015"
		LF   = "\012"
		EOL  = CR + LF

		### Class attributes
		@@MTU = 4096				# Maximum Transmissable Unit
		@@SelectTimeout = 0.75		# How long to wait on select() before looping
		@@Instance = nil			# The singleton instance

		### Make the new method private, as this class is a singleton
		private_class_method :new

		### METHOD: instance
		### Return the console output filter instance, creating it if necessary.
		def ConsoleOutputFilter.instance
			@@Instance ||= new()
		end

		protected
		def initialize
			super()

			@readBuffer = ''
			@readMutex = Sync.new
			@writeBuffer = ''
			@writeMutex = Sync.new

			@mode = ''
			@shutdown = false

			$stderr.puts "Starting IO thread"
			@ioThread = Thread.new { _ioThreadRoutine() }
			@ioThread.abort_on_exception = true
		end


		#######################################################################
		###	P U B L I C   M E T H O D S
		#######################################################################
		public

		# Accessors
		attr_reader :readBuffer, :writeBuffer, :ioThread

		### METHOD: handleOutputEvents( *events )
		### Handle an output event by appending its data to the output buffer
		def handleOutputEvents( *events )
			return nil if @shutdown

			events = super( events )
			events.flatten!

			unless events.empty?
				_debugMsg( 1, "Handling #{events.size} output events." )

				# Lock the output event queue and add the events we've been given to it
				_debugMsg( 1, "Appending '" + events.collect {|e| e.data }.join("") + "' to the output buffer." )
				@writeMutex.synchronize(Sync::EX) {
					@writeBuffer << events.collect {|e| e.data }.join("")
				}
			end

			# We're snarfing up all outbound events, so just return an empty array
			return []
		end


		### METHOD: handleInputEvents( *events )
		### Handle input events
		def handleInputEvents( *events )
			return nil if @shutdown
			super( *events )
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
			@ioThread.raise Shutdown
			super
		end


		#######################################################################
		###	P R O T E C T E D   M E T H O D S
		#######################################################################
		protected

		### (PROTECTED) METHOD: _ioThreadRoutine( socket )
		###	Thread routine for socket IO multiplexing. Reads data from queued output
		###		events and sends it to the remote client, and creates new input events
		###		from user input.
		def _ioThreadRoutine
			_debugMsg( 1, "In IO thread routine." )

			### Multiplex I/O, catching IO exceptions
			begin
				readable = []
				writeable = []

				### Loop until we break or get shut down
				loop do
					res = select( [$stdin], [$stdout] )

					unless res.nil?

						readable, writable = res

						### Read any input from the socket if it's ready
						unless readable.empty?
							@readMutex.synchronize(Sync::EX) {
								@readBuffer += $stdin.sysread( @@MTU )
								_debugMsg( 5, "Read data in select loop (@readBuffer = '#{@readBuffer}', " +
										  "length = #{@readBuffer.length})." )

								unless @readBuffer.empty?
									_debugMsg( 4, "Read buffer has stuff in it. Trying to get input events from it." )
									@readBuffer = _parseRawInput( @readBuffer )
								end
							}
						end

						### Write any buffered output to the socket if we have
						### output pending and the output IO is writable
						unless writable.empty? || @writeBuffer.empty?
							_debugMsg( 5, "Writing in select loop (@writebuffer = '#{@writeBuffer}')." )
							@writeMutex.synchronize(Sync::EX) {
								bytesWritten = $stdout.syswrite( @writeBuffer )
								@writeBuffer[0 .. bytesWritten] = ''
							}
						end
					end
				end

			### Handle EOF on the socket by setting the state and 
			rescue EOFError => e
				engine.dispatchEvents( LogEvent.new("info", "ConsoleOutputFilter shutting down: #{e.message}") )

			rescue Shutdown
				$stdout.syswrite( "\n\n>>> Disconnecting <<<\n\n" )

			### Just log any other caught exceptions (for now)
			rescue StandardError => e
				_debugMsg( 1, "EXCEPTION: ", e )
				engine.dispatchEvents( LogEvent.new("error","Error in ConsoleOutputFilter IO routine: #{e.message}") )

			### Make sure that the handler is set to the disconnected state and
			### clean up the socket when we're leaving
			ensure
				_debugMsg( 1, "In console IO thread routine's cleanup (#{$@.to_s})." )
				$stdout.flush
			end

			@shutdown = true
		end

		
		### (PROTECTED) METHOD: _parseRawInput( rawBuffer )
		### Parse the given raw buffer and return input events
		def _parseRawInput( rawBuffer )
			newInputEvents = []

			# Split input lines by CR+LF and strip whitespace before
			# creating an event
			rawBuffer.gsub!( /^([^\n]*)\n/ ) {|s|
				_debugMsg( 5, "Read a line: '#{s}' (#{s.length} bytes)." )

				_debugMsg( 4, "Creating an input event for input = '#{s.strip}'" )
				newInputEvents.push( InputEvent.new(s.strip) )
				
				""
			}

			queueInputEvents( *newInputEvents )
			return rawBuffer
		end
 
	end # class ConsoleOutputFilter
end # module MUES


