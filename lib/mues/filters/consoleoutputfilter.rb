#!/usr/bin/ruby
###########################################################################
=begin

=ConsoleOutputFilter.rb

== Name

ConsoleOutputFilter - A console output filter class

== Synopsis

  require "mues/filters/ConsoleOutputFilter"
  
  cof = MUES::ConsoleOutputFilter.new()

== Description

This class is an IOEventFilter which outputs to and takes input from the console
on which the Engine is running. It is a singleton.

== Classes
=== MUES::ConsoleOutputFilter
==== Public Methods

--- MUES::ConsoleOutputFilter#instance

    Return the console output filter instance, creating it if necessary.

--- MUES::ConsoleOutputFilter#ioThread

    Return the filter^s input thread object.

--- MUES::ConsoleOutputFilter#handleOutputEvents( *events )

    Handle an output event by appending its data to the output buffer

--- MUES::ConsoleOutputFilter#handleInputEvents( *events )

    Handle input events.

--- MUES::ConsoleOutputFilter#puts( aString )

    Append a string directly onto the output buffer. Useful when doing
    direct output and flush.

--- MUES::ConsoleOutputFilter#shutdown

    Signal the input thread to shut down and stop the filter.

==== Protected Methods

--- MUES::ConsoleOutputFilter#_inputThreadRoutine

    Thread routine for input.

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
	class ConsoleOutputFilter < IOEventFilter ; implements Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
		Rcsid = %q$Id: consoleoutputfilter.rb,v 1.5 2001/11/01 16:54:05 deveiant Exp $
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

			@shutdown = false

			$stderr.puts "Starting IO thread"
			@ioThread = Thread.new { _inputThreadRoutine() }
			@ioThread.abort_on_exception = true
		end


		#######################################################################
		###	P U B L I C   M E T H O D S
		#######################################################################
		public

		# Accessors
		attr_reader :ioThread

		### METHOD: handleOutputEvents( *events )
		### Handle an output event by appending its data to the output buffer
		def handleOutputEvents( *events )
			return nil if @shutdown

			events = super( events )
			events.flatten!

			$stdout.print events.collect {|e| e.data }.join("")
			$stdout.flush

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
			$stdout.puts aString
		end

		### METHOD: shutdown
		### Shut the filter down, signalling the IO thread to shut down.
		def shutdown
			@ioThread.raise Shutdown
			super
		end


		#######################################################################
		###	P R O T E C T E D   M E T H O D S
		#######################################################################
		protected

		### (PROTECTED) METHOD: _inputThreadRoutine
		### Thread routine for input.
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


