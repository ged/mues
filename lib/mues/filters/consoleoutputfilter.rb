#!/usr/bin/ruby
#
# This file contains the MUES::ConsoleOutputFilter class, which is a derivative
# of the MUES::IOEventFilter class. It outputs to and takes input from the
# console on which the Engine is running. It is a singleton.
# 
# == Synopsis
# 
#   require "mues/filters/ConsoleOutputFilter"
#   
#   cof = MUES::ConsoleOutputFilter.instance
# 
# == Rcsid
# 
# $Id: consoleoutputfilter.rb,v 1.7 2002/08/01 03:14:29 deveiant Exp $
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

require "sync"

require "mues"
require "mues/Events"
require "mues/Exceptions"
require "mues/PollProxy"
require "mues/filters/IOEventFilter"

module MUES

	# A console input/output filter class. Implements MUES::Debuggable.
	class ConsoleOutputFilter < IOEventFilter ; implements MUES::Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
		Rcsid = %q$Id: consoleoutputfilter.rb,v 1.7 2002/08/01 03:14:29 deveiant Exp $
		DefaultSortPosition = 300

		# Legibility constants
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

		### Return the console output filter instance, creating it if necessary.
		def ConsoleOutputFilter.instance
			@@Instance ||= new()
		end

		### Initialize the console output filter.
		def initialize( io, pollProxy, sortOrder=DefaultSortPosition ) # :no-new:
			checkType( io, IO )
			checkType( pollProxy, MUES::PollProxy )
			super( sortOrder )

			@io = io
			@pollProxy = pollProxy

			@readBuffer = ''
			@writeBuffer = ''
			@writeMutex = Sync.new

			@shutdown = false
		end


		######
		public
		######

		### Handle the specified input <tt>events</tt> (MUES::InputEvent objects).
		def handleInputEvents( *events )
			return events if @shutdown
			return nil unless @pollProxy.registered?

			return super( *events )
		end


		### Handle the specified output <tt>events</tt> (MUES::OutputEvent objects).
		def handleOutputEvents( *events )
			events = super( *events )
			events.flatten!

			debugMsg( 3, "Handling #{events.size} output events." )

			# If we're not in a connected state, just return the array we're given
			return events if @shutdown

			# If we're no longer registered with the Poll object, we're finished.
			return nil unless @pollProxy.registered?

			# Lock the output event queue and add the events we've been given to it
			debugMsg( 5, "Appending '" + events.collect {|e| e.data }.join("") + "' to the output buffer." )
			appendToWriteBuffer( events.collect {|e| e.data }.join("") )

			# We're snarfing up all outbound events, so just return an empty array
			return []
		end


		### Append a string directly onto the output buffer with a
		### line-ending. Useful when doing direct output and flush.
		def puts( aString )
			appendToWriteBuffer( aString + "\n" )
		end


		### Append a string directly onto the output buffer without a line
		### ending. Useful when doing direct output and flush.
		def write( aString )
			appendToWriteBuffer( aString )
		end


		### Start the filter
		def start( stream )
			super( stream )
			@writeMutex.synchronize( Sync::EX ) {
				@poll.register( Poll::IN, method(:handlePollEvent) )
				@poll.addMask( Poll::OUT ) unless @writeBuffer.empty?
			}
			@state = State::CONNECTED
		end

		### Shut the filter down, disconnecting from the remote host.
		def stop( stream )
			self.sendShutdownMessage if @pollObj.registered?
			self.shutdown
			@state = State::DISCONNECTED
			super( stream )
		end


		#########
		protected
		#########

		### The thread routine for the filter's IO thread.
		def inputThreadRoutine
			begin
				$stdin.each {|line|
					queueInputEvents( InputEvent.new(line.strip) )
				}

			### Handle EOF on the socket by setting the state and 
			rescue EOFError => e
				engine.dispatchEvents( LogEvent.new("info", "ConsoleOutputFilter shutting down: #{e.message}") )

			### Shutdown
			rescue Shutdown
				$stderr.print( "\n\n>>> Disconnecting <<<\n\n" )

			### Just log any other caught exceptions (for now)
			rescue StandardError => e
				debugMsg( 1, "EXCEPTION: ", e )
				engine.dispatchEvents( LogEvent.new("error","Error in ConsoleOutputFilter input routine: #{e.message}") )

			### Make sure that the handler is set to the disconnected state and
			### clean up the socket when we're leaving
			ensure
				$stdout.flush
				debugMsg( 1, "In console input thread routine's cleanup (#{$@.to_s})." )
			end

			@shutdown = true
		end

		
	end # class ConsoleOutputFilter
end # module MUES


