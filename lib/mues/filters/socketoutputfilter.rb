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
# == Subversion ID
# 
# $Id$
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

require 'mues/object'
require 'mues/events'
require 'mues/exceptions'
require 'mues/filters/outputfilter'

module MUES

	### A derivative of MUES::IOEventFilter that collects input from and sends
	### output to a TCPSocket.
	class SocketOutputFilter < MUES::OutputFilter ; implements MUES::Debuggable

		include MUES::TypeCheckFunctions

		### A container module for MUES::SocketOutputFilter state contants.
		module State
			DISCONNECTED = 0
			CONNECTED = 1
		end

		### Class constants

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# Default filter sort order number (See MUES::IOEventFilter)
		DefaultSortPosition = 15

		# Default assumption about how big the remote console is
		DefaultWindowSize = { 'height' => 23, 'width' => 80 }

		# The reactor events to react to
		HandledReactorEvents = [ :read, :write, :error ]

		# Legibility constants
		NULL = "\000"
		CR   = "\015"
		LF   = "\012"
		EOL  = CR + LF


		### Class globals

		# Maximum transmissable unit (chunk size)
		@@MTU = 4096

		# Number of seconds to use as a timeout in the select loop
		@@SelectTimeout = 0.1


		### Create and return a new socket output filter with the specified
		### <tt>socket</tt> (an IPSocket object), <tt>reactorProxy</tt>
		### (MUES::ReactorProxy object), and an optional <tt>sortOrder</tt>.
		def initialize( socket, reactorProxy, originListener, sortOrder=DefaultSortPosition )
			checkType( socket, IPSocket )
			checkType( reactorProxy, MUES::ReactorProxy )
			checkType( originListener, MUES::SocketListener )

			@socket = socket
			@reactorProxy = reactorProxy
			super( socket.peeraddr[2], originListener, sortOrder )

			@readBuffer		= ''
			@writeBuffer	= ''
			@writeMutex		= Sync.new
			@state			= State::DISCONNECTED
			@remoteHost		= socket.peeraddr[2]
			@remoteIp		= socket.peeraddr[3]
			@windowSize		= DefaultWindowSize.dup
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

		# The IP of the remote host
		attr_reader :remoteIp

		# A hash describing the client's window size (<tt>'height'</tt> and
		# <tt>'width'</tt> keys, Fixnum values).
		attr_reader :windowSize


		### Returns <tt>true</tt> if the socket peer is from IP '127.0.0.1'.
		def isLocal?
			return @remoteIp == "127.0.0.1"
		end


		### Handle the specified input <tt>events</tt> (MUES::InputEvent objects).
		def handleInputEvents( *events )
			return events unless @state == State::CONNECTED
			return nil unless @reactorProxy.registered?

			return super( *events )
		end


		### Handle the specified output <tt>events</tt> (MUES::OutputEvent objects).
		def handleOutputEvents( *events )
			events = super( *events )
			events.flatten!

			debugMsg( 3, "Handling #{events.size} output events." )

			# If we're not in a connected state, just return the array we're given
			return events unless @state == State::CONNECTED

			# If we're no longer registered with the Reactor object, we're finished.
			return nil unless @reactorProxy.registered?

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


		### Start the filter, returning a (potentially empty) Array of
		### consequential events.
		def start( stream )
			results = super( stream )

			@writeMutex.synchronize( Sync::EX ) {
				@reactorProxy.register( :read, &method(:handleReactorEvent) )
				@reactorProxy.enableEvents( :write ) unless @writeBuffer.empty?
			}
			@state = State::CONNECTED

			return results
		end

		### Shut the filter down, disconnecting from the remote host.
		def stop( stream )
			self.sendShutdownMessage if @reactorProxy.registered?
			self.shutdown
			return super( stream )
		end



		#########
		protected
		#########

		### Append the specified <tt>strings</tt> to the output buffer and mask
		### the Reactor object to receive writable condition events.
		def appendToWriteBuffer( *strings )
			data = strings.join("")

			@writeMutex.synchronize(Sync::EX) {
				@writeBuffer << data

				# If there's something in the output buffer, register this filter as
				# interested in its socket being writable.
				unless @writeBuffer.empty?
					@reactorProxy.enableEvents( :write )
				end
			}
		end


		### Handler routine for Reactor events. Reads data from queued
		### output events, sends it to the remote client, and creates new input
		### events from user input via the socket.
		def handleReactorEvent( socket, event )
			debugMsg( 5, "Got reactor event: #{event.class.name}: %x" % event )

			### Handle invalid file descriptor
			case event
			when :error
				so_error = socket.getsockopt( Socket::SOL_SOCKET, Socket::SO_ERROR )
				self.log.error( "Socket error: #{so_error.inspect}." )
				self.shutdown

			### Read any input from the socket if it's ready
			when :read
				readData = socket.sysread( @@MTU )
				debugMsg( 5, "Read %d bytes in reactor event handler (readData = %s)." %
						[ readData.length, readData.inspect ] )
				handleRawInput( readData )

			### Write any buffered output to the socket if we have output
			### pending and the socket is writable
			when :write
				debugMsg( 5, "Writing %d bytes in reactor event handler "\
					"(@writebuffer = %s)." %
					[ @writeBuffer.length, @writeBuffer.inspect ])

				@writeMutex.synchronize(Sync::EX) {
					bytesWritten = socket.syswrite( @writeBuffer )
					debugMsg( 5, "Wrote %d bytes." % bytesWritten )
					@writeBuffer[0 .. bytesWritten] = ''

					if @writeBuffer.empty?
						debugMsg( 4, "Disabling write event" )
						@reactorProxy.disableEvents( :write )
					end
				}

			else
				self.log.notice "Unhandled Reactor event in %s: %p" %
					[ self.class.name, event ]
			end

		rescue => e
			self.log.error( "Error on #{socket.inspect}: #{e.message}. Shutting filter down." )
			self.shutdown
		end


		### Shut the filter down.
		def shutdown
			self.log.info( "Filter #{self.to_s} shutting down." )

			@state = State::DISCONNECTED

			# Unregister the filter from the reactor object, which indicates
			# that it is to be removed from the stream, if it's not already
			# being done (ie., from #stop).
			@reactorProxy.unregister

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


