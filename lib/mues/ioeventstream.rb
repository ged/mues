#!/usr/bin/ruby -w
###########################################################################
=begin
= IOEventStream
== Name

MUES::IOEventStream - An IO event handler stack class

== Synopsis

  require "mues/IOEventStream"
  require "mues/IOEventFilters"
  require "mues/Events"

  # Get a client connection from the listener socket
  sock = listenSocket.accept

  # Create a new IO event handler stream and put an input and output event
  # handler into it
  @stream = MUES::IOEventStream.new

  # Create three IO event filters, one which handles TCP/IP socket IO, one which
  # does the login sequence, trapping any input itself until the connecting user
  # successfully logs in, and a command handler which will accept commands from
  # user input and execute them once the login filter is out of the way
  inputHandler = MUES::CommandIOEventFilter.new( COMMANDS_MORTAL|COMMANDS_IMMORTAL )
  loginHandler = MUES::LoginInputFilter.new( playerDbHandle, 3 )
  outputHandler = MUES::SocketIOEventFilter.new( sock )

  # Add the filters. They can be added in any order, as they will be sorted
  # sensibly after they are added.
  @stream.addHandlers( inputHandler, loginHandler, outputHandler )

  connectMsg = MUES::OutputEvent.new( "Welcome to ExperimentalMUD." )
  @stream.addOutputEvents( loginMsg )

== Description

(({MUES::IOEventStream})) is a filtered input/output stream class for the
intercommunication of objects in the FaerieMUD engine. It it primarily used for
input and output events bound for or coming from the socket object contained in
a ((<MUES::Player>)) object, but it can be used to route input and output events
for any object which requires a complex I/O abstraction.

The stream itself is only a container; it is essentially just a stack of filter
objects, each of which can act upon the input and output events flowing through
the stream. A filter may, depending on its purpose and configuration, act on the
I/O events in the stream in many different ways. It can redirect, modify,
duplicate, and/or inject new events based on the contents of event.

The stream is bi-directional, meaning that all filters contained in the stream
see both input and output events. This allows a single filter to act on events
flowing in both directions.

The stream also contains its own thread of execution, so I/O in it is processed
independently of the main thread of execution.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "thread"
require "timeout"

require "mues/Namespace"
require "mues/IOEventFilters"
require "mues/Events"
require "mues/Debugging"

module MUES

	### CLASS: IOEventStream < Object
	class IOEventStream < Object
		module State
			SHUTDOWN = 0
			RUNNING = 1
		end

		include Debuggable
		include Event::Handler
		include IOEventStream::State

		@@IoLoopInterval = 0.5

		### METHOD: initialize( *filters )
		### Initialize a newly-created stream object with the specified filters, if
		###	any. Also adds default filters to the top and bottom of the stack.
		def initialize( *filters )
			checkEachType( filters, IOEventFilter )
			super()

			### Start the stack out with default filters and the ones specified in
			### the constructor ones
			@filters = [ DefaultInputFilter.new, filters, DefaultOutputFilter.new ].flatten
			@filterMutex = Mutex.new
			@inputEvents = []
			@inputEventMutex = Mutex.new
			@outputEvents = []
			@outputEventMutex = Mutex.new
			@state = RUNNING
			@sleepTime = 0.0
			@streamCond = ConditionVariable.new
			@streamThread = Thread.new { _doStreamThreadRoutine }
		end

		### METHOD: addFilters( *filters)
		### Add the specified filters to the stream
		def addFilters( *filters )
			_debugMsg( 1, "Adding #{filters.size} filters to stream #{self.id}" )

			@filterMutex.synchronize {
				@filters |= filters
			}
		end

		### METHOD: removeFilters( *filters )
		### Remove the specified filters from the stream
		def removeFilters( *filters )
			_debugMsg( 1, "Removing #{filters.size} filters from stream #{self.id}" )

			returnFilters = []
			@filterMutex.synchronize {
				returnFilters = @filters & filters
				@filters -= filters
			}

			return returnFilters
		end


		### METHOD: removeFiltersOfType( aClass )
		### Remove all handlers of the specified type from the IOEventStream. The
		### default handlers cannot be removed, however.
		def removeFiltersOfType( aClass )
			checkType( aClass, Class )
			removeFilters( @filters.find_all {|filter| filter.is_a?( aClass )} )
		end


		### METHOD: addEvents( *events )
		### Add the specified events to whichever side of the stream they need to be
		### added to.
		def addEvents( *events )
			events.flatten!

			addOutputEvents( events.find_all {|ev| ev.is_a? OutputEvent} )
			addInputEvents( events.find_all {|ev| ev.is_a? InputEvent} )
		end

		### METHOD: addOutputEvents( *events )
		### Add the specified output events to the stream for processing.
		def addOutputEvents( *events )
			events.flatten!

			_debugMsg( 1, "Adding #{events.size} output events to the queue for the next run." )

			@outputEventMutex.synchronize do
				@outputEvents += events
			end
		end


		### METHOD: fetchOutputEvents
		### Fetch any pending output events for processing, clearing the output events array
		def fetchOutputEvents
			events = []
			@outputEventMutex.synchronize do
				events += @outputEvents
				@outputEvents.clear
			end

			_debugMsg( 1, "Fetched #{events.size} queued output events." )
			return events
		end


		### METHOD: addInputEvents( *events )
		### Add the specified input events to the stream for processing.
		def addInputEvents( *events )
			events.flatten!

			@inputEventMutex.synchronize do
				@inputEvents += events
			end
		end


		### METHOD: fetchInputEvents( *events )
		### Fetch any pending input events for processing, clearing the input events array
		def fetchInputEvents
			events = []
			@inputEventMutex.synchronize do
				events += @inputEvents
				@inputEvents.clear
			end

			return events
		end


		### METHOD: shutdown
		### Shut down all the filters contained in the stream and prepare for destruction.
		def shutdown
			_debugMsg( 1, "Shutting down event stream #{self.id}." )
			@filterMutex.synchronize do
				@state = SHUTDOWN
			end

			### Shut each filter down and clear them
			@filters.each do |filter|
				filter.shutdown
			end
			@filters.clear

			### Join on the stream's thread
			begin
				timeout( 2.0 ) do
					@streamThread.join
				end
			rescue TimeoutError
				@streamThread.kill
			end
			
			return true
		end


		#############################################################################
		###	P R O T E C T E D   M E T H O D S
		#############################################################################
		protected

		### (PROTECTED) METHOD: _doStreamThreadRoutine
		### Procedure that is run by the stream's thread which moves events through
		### the stream as they are generated/added.
		def _doStreamThreadRoutine

			while @state == RUNNING do

				startTime = Time.now

				_filterInputEvents()
				_filterOutputEvents()

				### Calculate how much time we have left in this loop, and catch a
				### quick nap if there's time
				sleepTime = @@IoLoopInterval - ( Time.now - startTime )
				@sleepTime = sleepTime
				sleep sleepTime if sleepTime > 0
			end
			
		end

		### (PROTECTED) METHOD: _filterInputEvents
		### Filter any input events that are currently queued through the stream's
		### filters. The filters are called in order from output to input.
		def _filterInputEvents
			return unless @state == RUNNING

			### Get the currently queued input events and clear the queue
			events = fetchInputEvents()
			events.flatten!
			_debugMsg( 1, "#{events.size} input events to filter." )

			### Delegate the list of events to each filter in turn, and catch any
			### that are returned for the next filter
			@filters.sort.each do |filter|
				_debugMsg( 1, "Sending #{events.size} input events to a #{filter.class.name}." )
				results = filter.handleInputEvents( events )
				_debugMsg( 1, "Filter returned #{results.size} events for the next filter." ) if results.is_a? Array
				if ( results.nil? || filter.isFinished ) then
					_debugMsg( 1, "#{filter.to_s} indicated it was finished. Removing it from the stream." )
					removeFilters( filter )
					oev = filter.queuedOutputEvents
					_debugMsg( 1, "Adding #{oev.size} output events from finished filter to queue for next cycle." )
					addOutputEvents( oev )
					events = filter.queuedInputEvents
					next
				end
				_debugMsg( 1, "#{results.size} events left after filtering." )
				events = results.flatten
			end

			### The filters should handle all events...
			raise UnhandledEventError, events[0] if events.size > 0
		end


		### (PROTECTED) METHOD: _filterOutputEvents
		### Filter any output events that are currently queued through the stream's
		### filters. The filters are called in order from output to output.
		def _filterOutputEvents
			return unless @state == RUNNING

			### Get the currently queued output events and clear the queue
			events = fetchOutputEvents()
			_debugMsg( 1, "#{events.size} output events to filter." )

			### Delegate the list of events to each filter in turn, and catch any
			### that are returned for the next filter
			@filters.sort.reverse.each do |filter|

				_debugMsg( 1, "Sending #{events.size} output events to a #{filter.class.name}." )
				results = filter.handleOutputEvents( *events )
				_debugMsg( 1, "Filter returned #{results.size} events for the next filter." ) if results.is_a? Array

				# If the filter returned nil or its isFinished flag is set,
				# get all of its queued events and remove it from the stream.
				if ( results.nil? || filter.isFinished ) then
					_debugMsg( 1, "#{filter.to_s} indicated it was finished. Removing it from the stream." )
					removeFilters( filter )
					iev = filter.queuedInputEvents
					_debugMsg( 1, "Adding #{iov.size} input events from finished filter to queue for next cycle." )
					addInputEvents( iev )
					events = filter.queuedOutputEvents
					next
				end

				events = results.flatten
			end

			### The filters should handle all events...
			events.flatten!
			raise UnhandledEventError, events[0] if events.size > 0
		end


		### Event handlers

		### (PROTECTED) METHOD: _handleOutputEvent( event )
		### Handle incoming IO events
		def _handleOutputEvent( event )
			checkType( event, OutputEvent )
			return unless @state == RUNNING

			addOutputEvents( event )
		end

	end #class IOEventStream

end #module MUES
