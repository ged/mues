#!/usr/bin/ruby
# 
# This file contains the MUES::SocketOutputFilter class, which is a filter for
# MUES::IOEventStream objects. Instances of this class are participants in an
# IOEventStream chain of responsibility, sending output and reading input from
# an IPSocket.
# 
# == Synopsis
# 
#   sock = listener.accept
#   sofilter = MUES::SocketOutputFilter.new( sock )
# 
# == Rcsid
# 
# $Id: socketoutputfilter.rb,v 1.11 2002/08/01 03:14:40 deveiant Exp $
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

require 'sync'
require 'socket'
require 'poll'

require 'mues'
require 'mues/Events'
require 'mues/Exceptions'
require 'mues/filters/IOEventFilter'

module MUES

	### A derivative of MUES::IOEventFilter that collects input from and sends
	### output to a TCPSocket.
	class SocketOutputFilter < IOEventFilter ; implements MUES::Debuggable

		include MUES::ServerFunctions, MUES::TypeCheckFunctions

		### A container module for MUES::SocketOutputFilter state contants.
		module State
			DISCONNECTED = 0
			CONNECTED = 1
		end

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.11 $ )[1]
		Rcsid = %q$Id: socketoutputfilter.rb,v 1.11 2002/08/01 03:14:40 deveiant Exp $
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
		### <tt>socket</tt> (an IPSocket object), <tt>pollProxy</tt>
		### (MUES::PollProxy object), and an optional <tt>sortOrder</tt>.
		def initialize( socket, pollProxy, sortOrder=DefaultSortPosition )
			checkType( socket, IPSocket )
			checkType( pollProxy, MUES::PollProxy )

			@socket = socket
			@pollProxy = pollProxy
			super( sortOrder )

			@readBuffer = ''
			@writeBuffer = ''
			@writeMutex = Sync.new
			@state = State::DISCONNECTED
			@remoteHost = socket.peeraddr[2]
			@windowSize = DefaultWindowSize.dup
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


		### Handle the specified input <tt>events</tt> (MUES::InputEvent objects).
		def handleInputEvents( *events )
			return events unless @state == State::CONNECTED
			return nil unless @pollProxy.registered?

			return super( *events )
		end


		### Handle the specified output <tt>events</tt> (MUES::OutputEvent objects).
		def handleOutputEvents( *events )
			events = super( *events )
			events.flatten!

			debugMsg( 3, "Handling #{events.size} output events." )

			# If we're not in a connected state, just return the array we're given
			return events unless @state == State::CONNECTED

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

		### Append the specified <tt>strings</tt> to the output buffer and mask
		### the Poll object to receive writable condition events.
		def appendToWriteBuffer( *strings )
			data = strings.join("")

			@writeMutex.synchronize(Sync::EX) {
				@writeBuffer << data

				# If there's something in the output buffer, register this filter as
				# interested in its socket being writable.
				unless @writeBuffer.empty?
					@pollProxy.addMask( Poll::OUT )
				end
			}
		end


		### Handler routine for Poll events. Reads data from queued
		### output events, sends it to the remote client, and creates new input
		### events from user input via the socket.
		def handlePollEvent( socket, mask )
			case mask

			### Handle invalid file descriptor
			when Poll::NVAL|Poll::HUP
				err = (mask == Poll::NVAL ? "Invalid file descriptor" : "Hangup")
				self.log.error( "#{err} for #{socket.inspect}" )
				self.shutdown

			### Handle socket errors
			when Poll::ERR
				so_error = socket.getsockopt( SOL_SOCKET, SO_ERROR )
				self.log.error( "Socket error: #{so_error.inspect}" )

			### Read any input from the socket if it's ready
			when Poll::RDNORM
				readData = socket.sysread( @@MTU )
				debugMsg( 5, "Read data in select loop (readData = '#{readData}', length = #{readData.length})." )
				handleRawInput( readData )

			### Write any buffered output to the socket if we have output
			### pending and the socket is writable
			when Poll::WRNORM
				debugMsg( 5, "Writing in select loop (@writebuffer = '#{@writeBuffer}')." )
				@writeMutex.synchronize(Sync::EX) {
					bytesWritten = socket.syswrite( @writeBuffer )
					@writeBuffer[0 .. bytesWritten] = ''

					@pollProxy.removeMask( Poll::WRNORM ) if @writeBuffer.empty?
				}

			else
				self.log.notice( "Unhandled Poll event in #{self.class.name}: '#{mask.inspect}'" )
			end
				
		end


		### Shut the filter down.
		def shutdown
			debugMsg( 4, "Filter #{self.inspect} shutting down." )

			# Unregister the filter from the poll object, which indicates that
			# it is to be removed from the stream, if it's not already being
			# done (ie., from #stop).
			@pollProxy.unregister

			@socket.flush
			@socket.shutdown( 2 )
			@socket.close
		end

		
		### Send a shutdown message to the client using unbuffered I/O on the
		### <tt>rawSocket</tt> specified, as we won't be around to fetch it from
		### the buffer.
		def sendShutdownMessage
			@socket.syswrite( @writeBuffer )
			@socket.syswrite( "\n>>> Disconnecting <<<\n\n" )
		end


		### Handle the given raw input <tt>data</tt> which has just been read
		### from the client socket.
		def handleRawInput( data )
			@readBuffer += data
			debugMsg( 5, "Handling raw input (@readBuffer = '#{@readBuffer}', " +
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
			inputBuffer.gsub!( /^([^#{CR}#{LF}]*)#{CR}#{LF}?/ ) {|s|
				debugMsg( 5, "Read a line: '#{s}' (#{s.length} bytes)." )

				debugMsg( 4, "Creating an input event for input = '#{s.strip}'" )
				newInputEvents.push( InputEvent.new("#{s.strip}") )
				
				""
			}

			queueInputEvents( *newInputEvents )
			return inputBuffer
		end
 
	end # class SocketOutputFilter
end # module MUES


