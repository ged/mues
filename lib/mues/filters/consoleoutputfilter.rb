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
# $Id: consoleoutputfilter.rb,v 1.13 2003/09/12 02:22:06 deveiant Exp $
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
require "thread"

require "mues/Object"
require "mues/Events"
require "mues/Exceptions"
require "mues/ReactorProxy"
require "mues/filters/OutputFilter"

module MUES

	# A console input/output filter class. Implements MUES::Debuggable.
	class ConsoleOutputFilter < MUES::OutputFilter ; implements MUES::Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q{$Revision: 1.13 $} )[1]
		Rcsid = %q$Id: consoleoutputfilter.rb,v 1.13 2003/09/12 02:22:06 deveiant Exp $
		DefaultSortPosition = 15

		### A container module for MUES::SocketOutputFilter state contants.
		module State
			STARTING = 0
			RUNNING = 1
			SHUTDOWN = 2
		end

		# The Reactor events to react to
		HandledReactorEvents = [ :read, :write, :error ]

		# Legibility constants
		NULL = "\000"
		CR   = "\015"
		LF   = "\012"
		EOL  = CR + LF

		MTU	 = 4096

		### Class attributes
		@instance = nil				# The singleton instance


		### Initialize the console output filter.
		def initialize( reactorProxy, originListener=MUES::Listener, sortOrder=DefaultSortPosition )
			checkType( reactorProxy, MUES::ReactorProxy )
			checkType( originListener, MUES::Listener )

			@reactorProxy		= reactorProxy

			@readBuffer		= ''
			@writeBuffer	= ''

			@writeMutex		= Mutex.new
			@writeCond		= ConditionVariable.new

			self.debugLevel = 5

			@state = State::STARTING
			super( "Console", originListener, sortOrder )

			self.log.info "Starting write thread."
			@outputThread = Thread::new { outputThreadRoutine() }
			@outputThread.desc = "Console IO filter write thread"
		end


		######
		public
		######

		### The console is, by definition, on the local machine, so this
		### overridden version always returns <tt>true</tt>.
		def isLocal?
			true
		end


		### Handle the specified input <tt>events</tt> (MUES::InputEvent objects).
		def handleInputEvents( *events )

			debugMsg( 3, "Handling #{events.size} input events." )

			# If the filter's finished, queue away the events and return the
			# signal to dispose of this filter.
			if self.finished? || @state == State::SHUTDOWN
				self.queueInputEvents( *events )
				debugMsg 4, "Finished filter returning nil."
				return nil
			end

			# If the filter's not in a connected state, just return the event array
			return events if @state == State::STARTING

			debugMsg( 3, "Passing #{events.length} input events to the superclass." )
			return super( *events )
		end


		### Handle the specified output <tt>events</tt> (MUES::OutputEvent objects).
		def handleOutputEvents( *events )
			events = super( *events )
			events.flatten!

			debugMsg( 3, "Handling #{events.size} output events." )

			# If the filter's finished, queue away the events and return the
			# signal to dispose of this filter.
			if self.finished? || @state == State::SHUTDOWN
				self.queueOutputEvents( *events )
				debugMsg 4, "Finished filter returning nil."
				return nil
			end

			# If the filter's not in a connected state, just return the event array
			return events if @state == State::STARTING

			# Lock the output event queue and add the events
			debugMsg( 5, "Appending '" + events.collect {|e| e.data }.join("") + "' to the output buffer." )
			appendToWriteBuffer( events.collect {|e| e.data }.join("") )

			# Handle all outbound events, so just return an empty array
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
			@reactorProxy.register( :read, method(:handleReactorEvent) )
			@state = State::RUNNING
		end


		### Shut the filter down, disconnecting from the remote host.
		def stop( stream )
			debugMsg 1, "Stopping %s" % self.to_s
			self.sendShutdownMessage if @reactorProxy.registered?
			self.shutdown
			rval = super( stream )
			debugMsg 3, "Stopping console filter, returning: %s" % rval.to_s

			@outputThread.join( 1.5 )

			return rval
		end



		#########
		protected
		#########

		### Routine for the thread that manages writes to STDOUT
		def outputThreadRoutine
			Thread.current.abort_on_exception = true

			# Wait for the filter to start
			debugMsg 2, "Waiting on running state"
			Thread::pass until @state == State::RUNNING

			# Start outputting the write buffer until shutdown
			while @state == State::RUNNING
				debugMsg 4, "Filter state is %d" % @state

				@writeMutex.synchronize {
					until @writeBuffer.empty?
						debugMsg 5, "Writing %d bytes" % @writeBuffer.length
						bytesWritten = $stdout.write( @writeBuffer )
						@writeBuffer.slice!( 0 .. (bytesWritten-1) )
					end

					$stdout.flush

					debugMsg 4, "Write buffer is empty. Waiting on output."
					@writeCond.wait( @writeMutex )
					debugMsg 3, "Got notification. Checking filter state."
				}
			end

			debugMsg 2, "State was %d. Exiting write loop." % @state
			
		rescue ::Exception => err
			self.log.error "%s caught an untrapped exception: %s\n\t%s" %
				[ self.to_s, err.message, err.backtrace.join("\n\t") ]
		end


		### Shut the filter down.
		def shutdown
			debugMsg 1, "Shutting filter down."

			# Set the state to shutdown and notify the writing thread
			@state = State::SHUTDOWN
			debugMsg 2, "Notifying write thread; State = %d" % @state
			@writeMutex.synchronize { @writeCond.signal }

			# Unregister the input IO
			self.log.info( "Filter #{self.to_s} shutting down." )
			@reactorProxy.unregister

			# Flag the filter as finished and notify the controlling stream
			self.finish
			notify_observers( self, 'input' )
		end


		### Send a shutdown message to STDOUT
		def sendShutdownMessage
			$stdout.write( @writeBuffer )
			$stdout.write( "\n>>> Disconnecting <<<\n\n" )
		end


		### Append the specified <tt>strings</tt> to the output buffer and mask
		### the Reactor object to receive writable condition events.
		def appendToWriteBuffer( *strings )
			data = strings.join("")
			return if data.empty?

			@writeMutex.synchronize {
				@writeBuffer << data
				@writeCond.signal unless @writeBuffer.empty?
			}
		end


		### Handler routine for Reactor events.
		def handleReactorEvent( io, event )
			debugMsg( 5, "Got reactor event: %p" % event )

			### Handle invalid file descriptor
			case event

			when :error
				self.log.error( "#{err} for #{io.inspect}" )
				self.shutdown

			### Read any input from the io if it's ready
			when :read
				readData = io.sysread( MTU )
				debugMsg( 5, "Read %d bytes in reactor event handler (readData = %s)." %
						[ readData.length, readData.inspect ] )
				handleRawInput( readData )

			# If the event contains bits we don't handle, log them
			else
				self.log.notice( "Unhandled Reactor event in #{self.class.name}: %o" %
								 ((event ^ HandledBits) & event) )
			end

		rescue => e
			self.log.error( "Error on #{io.inspect}: #{e.message}. Shutting filter down." )
			self.shutdown
		end


		### Handle the given raw input <tt>data</tt> which has just been read
		### from the client socket.
		def handleRawInput( data )
			@readBuffer += data
			debugMsg( 5, "Handling raw input (@readBuffer = #{@readBuffer.inspect}, " +
					  "length = #{@readBuffer.length})." )

			unless @readBuffer.empty?
				debugMsg( 4, "Read buffer is non-empty. Trying to get input events from it." )
				@readBuffer = parseInputBuffer( @readBuffer )
			end
		end

		
		### Parse input events from the given raw <tt>inputBuffer</tt> and
		### return the (possibly) modified buffer after queueing any input
		### events created.
		def parseInputBuffer( inputBuffer )
			newInputEvents = []

			# Split input lines by CR+LF and strip whitespace before
			# creating an event
			inputBuffer.gsub!( /^([^#{CR}#{LF}]*)(?:#{CR}|#{LF})+/ ) {|s|
				debugMsg( 5, "Read a line: '#{s}' (#{s.length} bytes)." )

				debugMsg( 4, "Creating an input event for input = '#{s.strip}'" )
				newInputEvents.push( InputEvent.new("#{s.strip}") )
				
				""
			}

			queueInputEvents( *newInputEvents )
			return inputBuffer
		end


		
	end # class ConsoleOutputFilter
end # module MUES


