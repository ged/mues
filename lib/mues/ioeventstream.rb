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
require "sync"
require "timeout"

require "mues/Namespace"
require "mues/IOEventFilters"
require "mues/Events"

module MUES

	### CLASS: IOEventStream < Object
	class IOEventStream < Object ; implements Debuggable

		### Set up some state constants
		module State
			SHUTDOWN	= 0
			RUNNING		= 1
		end
		include State

		# Import the default event handler dispatch method
		include Event::Handler

		### Class variables
		@@IoLoopInterval = 0.1

		### Accessors
		attr_reader		:filters, :inputEvents, :outputEvents, :state, :streamThread
		attr_accessor	:sleepTime

		### METHOD: new( *filters )
		### Instantiate and return a stream object with the specified filters, if
		###	any. Also adds default filters to the top and bottom of the stack.
		def initialize( *filters )
			checkEachType( filters, MUES::IOEventFilter )
			super()

			### Filter stack
			@filters = [ DefaultInputFilter.new, filters, DefaultOutputFilter.new ].flatten
			@filterMutex = Sync.new

			### Event arrays
			@inputEvents = []
			@inputEventMutex = Sync.new
			@outputEvents = []
			@outputEventMutex = Sync.new

			### IO signalling attributes
			@notificationMutex		= Mutex.new
			@notification			= ConditionVariable.new
			@notifyingInputObjects	= []
			@notifyingOutputObjects = []

			### Stream state attributes
			@state = RUNNING
			@paused = false
			@sleepTime = 0.0
			@streamThread = Thread.new { _streamThreadRoutine }
			@streamThread.abort_on_exception = true
			@streamThread.desc = "IOEventStream thread [Stream #{self.id}]"
		end


		### METHOD: update( subject, which )
		### Notify the stream that the subject specified has pending events.
		def update( subject, which )
			checkType( which, String )

			_debugMsg( 4, "Got '#{which}' notification from a #{subject.class.name}." )

			@notificationMutex.synchronize {
				case which
				when /input/i
					@notifyingInputObjects	|= [ subject ]

				when /output/i
					@notifyingOutputObjects	|= [ subject ]

				else
					raise ArgumentError, 
						"Second argument of update must be one of 'input' or 'output', was '#{which}'"
				end

				_debugMsg( 5, "Signalling for this update." )
				@notification.signal unless @paused
			}
		end


		### METHOD: addFilters( *filters)
		### Add the specified filters to the stream
		def addFilters( *filters )
			_debugMsg( 1, "Adding #{filters.size} filters to stream #{self.id}" )

			### Add each filter that isn't already in the stream, adding it to
			### the array of filters, and notifying each one that it should
			### start notifying this stream
			@filterMutex.synchronize(Sync::EX) {
				nonMemberSet = (filters - @filters)

				@filters += nonMemberSet
				nonMemberSet.each {|f| f.start( self ) }
			}

			_debugMsg( 2, "Stream now has #{@filters.size} filters." )
		end


		### METHOD: removeFilters( *filters )
		### Remove the specified filters from the stream
		def removeFilters( *filters )
			_debugMsg( 1, "Removing #{filters.size} filters from stream #{self.id}" )

			returnFilters = []

			### Remove each filter that is actually in the stream, notifying
			### each one that it should stop notifying this stream
			@filterMutex.synchronize(Sync::EX) {
				returnFilters = @filters & filters
				returnFilters.each {|f| f.stop( self ) }

				@filters -= filters
			}

			_debugMsg( 2, "Stream now has #{@filters.size} filters." )
			return returnFilters
		end


		### METHOD: removeFiltersOfType( aClass )
		### Remove all handlers of the specified type from the IOEventStream. The
		### default handlers cannot be removed, however.
		def removeFiltersOfType( aClass )
			checkType( aClass, ::Class )
			@filterMutex.synchronize( Sync::SH ) {
				removeFilters( @filters.find_all {|filter| filter.is_a?( aClass )} )
			}
		end


		### METHOD: addEvents( *events )
		### Add the specified events to whichever side of the stream they need to be
		### added to.
		def addEvents( *events )
			events.flatten!

			dispatch = [[],[],[]]
			ret = []

			events.each {|ev|
				case ev
				when OutputEvent
					dispatch[0].push ev

				when InputEvent
					dispatch[1].push ev

				when TickEvent
					dispatch[2].push ev

				else
					raise UnhandledEventError, ev
				end
			}
					
			addOutputEvents( *dispatch[0] )
			addInputEvents( *dispatch[1] )
			addTickEvents( *dispatch[2] )

			return ret
		end


		### METHOD: addOutputEvents( *events )
		### Add the specified output events to the stream for processing.
		def addOutputEvents( *events )
			events.flatten!

			_debugMsg( 3, "Adding #{events.size} output events to the queue for the next run." )

			@outputEventMutex.synchronize(Sync::EX) {
				@outputEvents += events
			}
			update( self, 'output' )
		end


		### METHOD: fetchOutputEvents
		### Fetch any pending output events for processing, clearing the output
		### events array
		def fetchOutputEvents
			events = []
			@outputEventMutex.synchronize(Sync::EX) {
				events += @outputEvents
				@outputEvents.clear
			}

			_debugMsg( 3, "Fetched #{events.size} queued output events." )
			return events
		end


		### METHOD: addInputEvents( *events )
		### Add the specified input events to the stream for processing.
		def addInputEvents( *events )
			events.flatten!

			@inputEventMutex.synchronize(Sync::EX) {
				@inputEvents += events
			}
			update( self, 'input' )
		end


		### METHOD: fetchInputEvents( *events )
		### Fetch any pending input events for processing, clearing the input
		### events array
		def fetchInputEvents
			events = []
			@inputEventMutex.synchronize(Sync::EX) {
				events += @inputEvents
				@inputEvents.clear
			}

			return events
		end


		### METHOD: shutdown
		### Shut down all the filters contained in the stream and prepare for destruction.
		def shutdown
			results = []

			_debugMsg( 1, "Shutting down event stream #{self.id}." )
			@filterMutex.synchronize(Sync::EX) {
				@state = SHUTDOWN

				### Shut each filter down and clear them
				@filters.reverse.each {|f|
					f.stop( self )
					results << f.shutdown
				}
				@filters.clear
			}

			unpause()

			@notificationMutex.synchronize {
				_debugMsg( 5, "Signalling for shutdown." )
				@notification.signal
			}

			### Join on the stream's thread
			unless @streamThread == Thread.current
				begin
					timeout( 2.0 ) do
						@streamThread.join
					end
				rescue TimeoutError
					@streamThread.kill
				end
			end

			return results.flatten
		end


		### METHOD: pause
		### Stop processing events until unpause() is called.
		def pause
			@notificationMutex.synchronize {
				@paused = true
			}
		end


		### METHOD: unpause
		### Stop processing events until unpause() is called.
		def unpause
			@notificationMutex.synchronize {
				@paused = false
				_debugMsg( 5, "Signalling for unpause." )
				@notification.signal unless ( @notifyingInputObjects + @notifyingOutputObjects ).empty?
			}
		end


		#############################################################################
		###	P R O T E C T E D   M E T H O D S
		#############################################################################
		protected

		### (PROTECTED) METHOD: _streamThreadRoutine
		### Procedure that is run by the stream's thread which moves events through
		### the stream as they are generated/added.
		def _streamThreadRoutine

			### While the stream is running, filter IOEvents through it,
			### stopping and waiting for the notification signal if there aren't
			### any objects with pending events
			while @state == RUNNING do

				@filterMutex.synchronize( Sync::SH ) {
					if ! @notifyingInputObjects.empty?
						_debugMsg( 4, "#{@notifyingInputObjects.length} input notifications." )
						_filterInputEvents()
					end

					if ! @notifyingOutputObjects.empty?
						_debugMsg( 4, "#{@notifyingOutputObjects.length} output notifications." )
						_filterOutputEvents()
					end
				}

				@notificationMutex.synchronize {
					if ( @notifyingInputObjects + @notifyingOutputObjects ).empty?
						_debugMsg( 3, "No pending IO. Waiting on notification (#{@notification.inspect}) for #{@notificationMutex.inspect}." )
						begin @notification.wait( @notificationMutex ) end until ! @paused
						_debugMsg(3, "Got notification. %s notifying objects." % [
									  ( @notifyingInputObjects + @notifyingOutputObjects ).length
								  ])
					end
				}
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
			_debugMsg( 2, ">>> Starting input cycle: #{events.size} input events to filter." )

			### Clear out the notifying objects, so we can use it to check for
			### objects that notify while we're running.
			@notificationMutex.synchronize { @notifyingInputObjects.clear }

			### Delegate the list of events to each filter in turn, and catch any
			### that are returned for the next filter
			@filterMutex.synchronize(Sync::SH) {
				@filters.sort.each {|filter|
					_debugMsg( 3, "Sending #{events.size} input events to a #{filter.class.name} "+
							   "(sort order = #{filter.sortPosition})." )
					results = filter.handleInputEvents( *events )
					_debugMsg( 3, "Filter returned #{results.size} events for the next filter." ) if results.is_a? Array
					if ( results.nil? || filter.isFinished )
						_debugMsg( 2, "#{filter.to_s} indicated it was finished. Removing it from the stream." )
						removeFilters( filter )
						oev = filter.queuedOutputEvents
						_debugMsg( 2, "Adding #{oev.size} output events from finished filter to queue for next cycle." )
						addOutputEvents( *oev )
						events = filter.queuedInputEvents
						next
					end
					_debugMsg( 3, "#{results.size} events left after filtering." )
					events = results.flatten
				}
			}

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
			_debugMsg( 2, "<<< Starting output cycle: #{events.size} output events to filter." )

			### Clear out the notifying objects, so we can use it to check for
			### objects that notify while we're running.
			@notificationMutex.synchronize { @notifyingOutputObjects.clear }

			### Delegate the list of events to each filter in turn, and catch any
			### that are returned for the next filter
			@filterMutex.synchronize(Sync::SH) {
				@filters.sort.reverse.each {|filter|

					_debugMsg( 3, "Sending #{events.size} output events to a #{filter.class.name} "+
							   "(sort order = #{filter.sortPosition})." )
					results = filter.handleOutputEvents( *events )
					_debugMsg( 3, "Filter returned #{results.size} events for the next filter." ) if results.is_a? Array

					# If the filter returned nil or its isFinished flag is set,
					# get all of its queued events and remove it from the stream.
					if ( results.nil? || filter.isFinished ) then
						_debugMsg( 2, "#{filter.to_s} indicated it was finished. Removing it from the stream." )
						removeFilters( filter )
						iev = filter.queuedInputEvents
						_debugMsg( 2, "Adding #{iev.size} input events from finished filter to queue for next cycle." )
						addInputEvents( *iev )
						events = filter.queuedOutputEvents
						next
					end

					events = results.flatten
				}
			}

			### The filters should handle all events...
			events.flatten!
			raise UnhandledEventError, events[0] if events.size > 0
		end


		### Event handlers

		### (PROTECTED) METHOD: _handleOutputEvent( event )
		### Handle incoming IO events
		def _handleOutputEvent( event )
			checkType( event, MUES::OutputEvent )
			return unless @state == RUNNING

			addOutputEvents( event )
		end

	end #class IOEventStream

end #module MUES
