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
# $Id: consoleoutputfilter.rb,v 1.6 2002/04/01 16:27:29 deveiant Exp $
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

	# A console input/output filter class. Implements MUES::Debuggable.
	class ConsoleOutputFilter < IOEventFilter ; implements MUES::Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: consoleoutputfilter.rb,v 1.6 2002/04/01 16:27:29 deveiant Exp $
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
		def initialize # :nodoc:
			super()

			@shutdown = false

			$stderr.puts "Starting IO thread"
			@ioThread = Thread.new { _inputThreadRoutine() }
			@ioThread.abort_on_exception = true
		end


		######
		public
		######

		# The IO thread object running in this filter
		attr_reader :ioThread


		### Handle output <tt>events</tt> by appending its data to the output
		### buffer.
		def handleOutputEvents( *events )
			return nil if @shutdown

			events = super( events )
			events.flatten!

			$stdout.print events.collect {|e| e.data }.join("")
			$stdout.flush

			# We're snarfing up all outbound events, so just return an empty array
			return []
		end


		### Handle input <tt>events</tt>.
		def handleInputEvents( *events )
			return nil if @shutdown
			super( *events )
		end


		### Append a string directly onto the output buffer. Useful when doing
		### direct output and flush.
		def puts( aString )
			$stdout.puts aString
		end


		### Shut the filter down, signalling the IO thread to shut down.
		def stop( filterObject )
			@ioThread.raise Shutdown
			super( filterObject )
		end


		#########
		protected
		#########

		### The thread routine for the filter's IO thread.
		def _inputThreadRoutine
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
				_debugMsg( 1, "EXCEPTION: ", e )
				engine.dispatchEvents( LogEvent.new("error","Error in ConsoleOutputFilter input routine: #{e.message}") )

			### Make sure that the handler is set to the disconnected state and
			### clean up the socket when we're leaving
			ensure
				$stdout.flush
				_debugMsg( 1, "In console input thread routine's cleanup (#{$@.to_s})." )
			end

			@shutdown = true
		end

		
	end # class ConsoleOutputFilter
end # module MUES


