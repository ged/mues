#!/usr/bin/ruby
# 
# This file contains the MUES::IOEventStream class, which is is a filtered
# input/output stream class used for the pipelining and abstraction of object
# inter-communication in the MUES engine. It is used to route input and output
# messages in the form of events for any object which requires a complex and
# mutable I/O abstraction. It is modelled after the <b>Chain of Responsibility</b>
# pattern from the [Design Patterns] book.
# 
# The stream itself is only a container; it is essentially just a stack of
# filters (MUES::IOEventFilter objects), each of which can potentially act upon
# the events flowing through the stream. A filter may act on the I/O events in
# the stream in many different ways, depending on its purpose and
# configuration. It can redirect, modify, duplicate, and/or inject new events
# based on the contents of each event.
# 
# The stream is bi-directional, meaning that all filters contained in the stream
# are given both input and output events. This allows a single filter to act on
# events flowing in both directions. If a filter is not interested in one
# direction, it can simply return the events it is given unchanged.
# 
# The stream starts its own Ruby thread at creation so that I/O in it is
# processed independently of the main EventQueue. It implements the
# <tt>Observer</tt> role of the Observer design pattern
# (http://patterndigest.com/patterns/Observer.html) so that filters with pending
# events may notify the stream they are associated with without the need to poll
# each filter constantly.
# 
# == Synopsis
# 
#   require "mues/IOEventStream"
#   require "mues/IOEventFilters"
#   require "mues/Events"
# 
#   # Create a new stream
#   stream = MUES::IOEventStream.new
# 
#   # Create three filters
#   sockFilter	= MUES::SocketOutputFilter.new( aSocket )
#   macroFilter	= MUES::MacroFilter.new( aUser )
#   shellFilter	= MUES::CommandShell.new( aUser )
# 
#   # Add the filters to the stream.
#   @stream.addHandlers( inputHandler, loginHandler, outputHandler )
# 
#   # Send output to the user
#   connectMsg = MUES::OutputEvent.new( "Welcome to ExperimentalMUD." )
#   @stream.addOutputEvents( loginMsg )
# 
# == Rcsid
# 
# $Id: ioeventstream.rb,v 1.18 2002/09/12 11:42:25 deveiant Exp $
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
require "timeout"

require "mues/Object"
require "mues/IOEventFilters"
require "mues/Events"
require "mues/WorkerThread"

module MUES

	### A filtered input/output stream class modelled after the Chain of
	### Responsibility design pattern.
	class IOEventStream < Object ; implements MUES::Debuggable

		# Import the default event handler dispatch method
		include MUES::Event::Handler, MUES::TypeCheckFunctions

		### Stream state constants module. It contains the following constants:
		###
		### [SHUTDOWN]
		###   The stream is shut down -- its thread is not running, and events
		###   passed to it will not be processed.
		###
		### [RUNNING]
		###   The stream is running.
		module State
			SHUTDOWN	= 0
			RUNNING		= 1
		end
		include State


		### Instantiate and return a stream object with the specified +filters+,
		### if any. Default filters (MUES::DefaultInputFilter and
		### MUES::DefaultOutputFilter) are automatically added to the ends of
		### the stack.
		def initialize( *filters )
			checkEachType( filters, MUES::IOEventFilter )
			super()

			### Filter stack
			@diFilter = DefaultInputFilter.new
			@doFilter = DefaultOutputFilter.new
			@filters = [ @diFilter, filters, @doFilter ].flatten
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
			@idle = false
			@paused = false
			@streamThread = Thread.new { streamThreadRoutine() }
			@streamThread.abort_on_exception = true
			@streamThread.desc = "IOEventStream thread [Stream #{self.id}]"
		end


		######
		public
		######

		# The array of filters currently in the stream
		attr_reader :filters

		# The array of pending input events.
		attr_reader :inputEvents

		# The array of pending output events.
		attr_reader :outputEvents

		# The state flag of the stream (See MUES::IOEventStream::State).
		attr_reader :state

		# Is the stream currently paused?
		attr_reader :paused
		alias :paused? :paused

		# Is the stream currently processing events?
		attr_reader :idle
		alias :idle? :idle

		# The stream's thread
		attr_reader :streamThread

		### Notify the stream that the subject specified (a MUES::IOEventFilter
		### object) has pending events of the type specified by +which+. Valid
		### values of +which+ are 'input' and 'output'.
		def update( subject, which )
			checkType( subject, MUES::IOEventFilter, MUES::IOEventStream )
			checkType( which, ::String )

			debugMsg( 4, "Got '#{which}' notification from a #{subject.class.name}." )

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

				debugMsg( 5, "Signalling for this update." )
				@notification.signal unless @paused
			}
			return true
		end


		### Add the specified +filters+ to the stream. They will be sorted into
		### the stream by their sortPosition (see
		### MUES::IOEventFilter#sortPosition).
		def addFilters( *filters )
			checkEachType( filters, MUES::IOEventFilter )
			debugMsg( 1, "Adding #{filters.size} filters to stream #{self.id}" )

			### Add each filter that isn't already in the stream, adding it to
			### the array of filters, and notifying each one that it should
			### start notifying this stream
			@filterMutex.synchronize(Sync::EX) {
				nonMemberSet = (filters - @filters)

				@filters += nonMemberSet
				nonMemberSet.each {|f| f.start( self )}
			}

			debugMsg( 2, "Stream now has #{@filters.size} filters." )
			return @filters.length
		end


		### Remove the specified <tt>filters</tt> from the stream, returning any
		### consequential events. The default filters cannot be removed. If no
		### <tt>filters</tt> are specified, all but the default filters are
		### removed.
		def removeFilters( *filters )
			if filters.empty?
				filters = @filters - [ @doFilter, @diFilter ]
			else
				checkEachType( filters, MUES::IOEventFilter )
				raise MUES::Exception, "Cannot remove the default input filter" if
					filters.include?( @diFilter )
				raise MUES::Exception, "Cannot remove the default output filter" if
					filters.include?( @doFilter )
			end

			results = []
			debugMsg( 1, "Removing #{filters.size} filters from stream #{self.id}" )

			### Remove each filter that is actually in the stream, notifying
			### each one that it should stop notifying this stream
			@filterMutex.synchronize(Sync::EX) {
				(@filters & filters).each {|f|
					results << f.stop( self )
				}

				@filters -= filters
			}

			debugMsg( 2, "Stream now has #{@filters.size} filters." )
			return results.flatten
		end


		### Remove all filters of the type specified by <tt>filterClass</tt> (a
		### Class object) from the IOEventStream, returning any consequential
		### events. The default filters cannot be removed.
		def removeFiltersOfType( filterClass )
			checkType( filterClass, ::Class )
			@filterMutex.synchronize( Sync::SH ) {
				removeFilters( findFiltersOfType(filterClass) )
			}
		end


		### Find and return an Array of all handlers of the type specified by
		### <tt>filterClass</tt> from the IOEventStream. If a block is given, it is
		### passed each matching filter, and the result is substituted for the
		### filter in the return value.
		def findFiltersOfType( filterClass ) # :yields: filter
			checkType( filterClass, ::Class )
			values = []

			@filterMutex.synchronize( Sync::SH ) {
				if block_given?
					@filters.find_all {|filter| filter.kind_of?(filterClass) }.each {|f|
						values << yield( f )
					}
				else
					values = @filters.find_all {|filter| filter.kind_of?(filterClass) }
				end
			}

			return values
		end


		### Add the specified +events+ to whichever side of the stream they need to be
		### added to.
		def addEvents( *events )
			events.flatten!
			input, output = [], []

			events.each {|ev|
				case ev
				when OutputEvent
					output << ev

				when InputEvent
					input << ev

				else
					raise UnhandledEventError, ev
				end
			}
					
			addOutputEvents( output )
			addInputEvents( input )

			return true
		end


		### Add the specified output +events+ to the stream for processing.
		def addOutputEvents( *events )
			events.flatten!

			debugMsg( 3, "Adding #{events.size} output events to the queue for the next run." )

			@outputEventMutex.synchronize(Sync::EX) {
				@outputEvents += events
			}
			update( self, 'output' )
		end


		### Fetch and return any output events pending processing, clearing the
		### output events array.
		def fetchOutputEvents
			events = []
			@outputEventMutex.synchronize(Sync::EX) {
				events += @outputEvents
				@outputEvents.clear
			}

			debugMsg( 3, "Fetched #{events.size} queued output events." )
			return events
		end


		### Add the specified input +events+ to the stream for processing.
		def addInputEvents( *events )
			events.flatten!

			@inputEventMutex.synchronize(Sync::EX) {
				@inputEvents += events
			}
			update( self, 'input' )
		end


		### Fetch and return any input events pending processing, clearing the
		### input events array.
		def fetchInputEvents
			events = []
			@inputEventMutex.synchronize(Sync::EX) {
				events += @inputEvents
				@inputEvents.clear
			}

			return events
		end


		### Shut down all the filters contained in the stream, shut down the
		### stream's thread, and prepare the stream for destruction.
		def shutdown
			results = []

			# Set the state flag and remove all filters
			debugMsg( 1, "Shutting down event stream #{self.id}." )
			@filterMutex.synchronize(Sync::EX) {
				@state = SHUTDOWN
				results << self.removeFilters
				@filters.clear
			}

			# Now unpause the stream and signal the stream's thread so it exits
			# (which it does when the state is set to anything but RUNNING).
			unpause()
			@notificationMutex.synchronize {
				debugMsg( 5, "Signalling for shutdown." )
				@notification.signal
			}

			### Join on the stream's thread with a timeout of 2 seconds
			if @streamThread != Thread.current
				@streamThread.join( 2 ) || @streamThread.kill
			elsif Thread.current != Thread.main
				Thread.current.exit
			end

			return results.flatten
		end


		### Stop processing events until #unpause is called.
		def pause
			@notificationMutex.synchronize { @paused = true }
		end


		### Resume processing events if the stream was paused.
		def unpause
			@notificationMutex.synchronize {
				@paused = false
				debugMsg( 5, "Signalling for unpause." )
				@notification.signal unless ( @notifyingInputObjects + @notifyingOutputObjects ).empty?
			}
		end


		#########
		protected
		#########

		### Stream thread routine -- moves events through the stream as they are
		### generated/added.
		def streamThreadRoutine

			### While the stream is running, filter IOEvents through it,
			### stopping and waiting for the notification signal if there aren't
			### any objects with pending events
			while @state == RUNNING do

				@filterMutex.synchronize( Sync::SH ) {
					if ! @notifyingInputObjects.empty?
						debugMsg( 4, "#{@notifyingInputObjects.length} input notifications." )
						filterInputEvents()
					end

					if ! @notifyingOutputObjects.empty?
						debugMsg( 4, "#{@notifyingOutputObjects.length} output notifications." )
						filterOutputEvents()
					end
				}

				@notificationMutex.synchronize {
					if ( @notifyingInputObjects + @notifyingOutputObjects ).empty?
						debugMsg( 3, "No pending IO. Waiting on notification " +
								   "(#{@notification.inspect}) for #{@notificationMutex.inspect}." )
						@idle = true
						begin @notification.wait( @notificationMutex ) end while self.paused?
						@idle = false
						debugMsg(3, "Got notification. %s notifying objects." % [
									  ( @notifyingInputObjects + @notifyingOutputObjects ).length
								  ])
					end
				}
			end
			
		end


		### Filter any input events that are currently queued through the stream's
		### filters. The filters are called in order from output to input.
		def filterInputEvents
			return unless @state == RUNNING

			### Get the currently queued input events and clear the queue
			events = fetchInputEvents()
			events.flatten!
			debugMsg( 2, ">>> Starting input cycle: #{events.size} input events to filter." )

			### Clear out the notifying objects, so we can use it to check for
			### objects that notify while we're running.
			@notificationMutex.synchronize { @notifyingInputObjects.clear }

			### Delegate the list of events to each filter in turn, and catch any
			### that are returned for the next filter
			@filterMutex.synchronize(Sync::SH) {
				@filters.sort.each {|filter|
					events = callFilterHandler( filter, "input", *events )
				}
			}

			### The filters should handle all events...
			raise UnhandledEventError, events[0] if events.size > 0
		end


		### Filter any output events that are currently queued through the stream's
		### filters. The filters are called in order from output to output.
		def filterOutputEvents
			return unless @state == RUNNING

			### Get the currently queued output events and clear the queue
			events = fetchOutputEvents()
			debugMsg( 2, "<<< Starting output cycle: #{events.size} output events to filter." )

			### Clear out the notifying objects, so we can use it to check for
			### objects that notify while we're running.
			@notificationMutex.synchronize { @notifyingOutputObjects.clear }

			### Delegate the list of events to each filter in turn, and catch any
			### that are returned for the next filter
			@filterMutex.synchronize(Sync::SH) {
				@filters.sort.reverse.each {|filter|
					events = callFilterHandler( filter, "output", *events )
				}
			}

			### The filters should handle all events...
			events.flatten!
			raise UnhandledEventError, events[0] if events.size > 0
		end


		### Handle IO events coming in from outside of the stream (ie., from the
		### Engine itself). This is useful for sending broadcast messages and
		### such through the Engine.
		def handleOutputEvent( event )
			checkType( event, MUES::OutputEvent )
			return unless @state == RUNNING

			addOutputEvents( event )
		end

		
		#########
		protected
		#########

		### Call the specified <tt>filter</tt>'s handler method with the
		### specified <tt>events</tt> for the specified
		### <tt>direction</tt>. Returns an Array of result events.
		def callFilterHandler( filter, direction, *events )
			debugMsg( 3, "Sending #{events.size} #{direction} events to a #{filter.class.name} "+
					 "(sort order = #{filter.sortPosition})." )

			results = filter.send( "handle%sEvents" % direction.capitalize, *events ) unless
				filter.isFinished?
			debugMsg( 3, "Filter returned #{results.size} events for the next filter." ) if
				results.is_a? Array

			# If the filter returned nil or its isFinished flag is set,
			# get all of its queued events and remove it from the stream.
			if ( results.nil? || filter.isFinished? )
				results ||= []

				debugMsg( 2, "#{filter.to_s} indicated it was finished. Removing it from the stream." )
				consequences = removeFilters( filter )
				results.push( *consequences ) if consequences.is_a?( Array ) && ! consequences.empty?

				opposite = (direction == "input" ? "Output" : "Input")

				requeuedEvents = filter.send( "queued%sEvents" % opposite )
				debugMsg( 2, "Adding %d %sEvents from finished filter to queue for next cycle." % [
							 requeuedEvents.size, opposite ])
				self.send( "add%sEvents" % opposite, *requeuedEvents )

				# Add any pending events to the array of results.
				consequences = filter.send("queued%sEvents" % direction.capitalize)
				results.push( *consequences ) if consequences.is_a?( Array ) && ! consequences.empty?
			elsif ( ! results.is_a? Array )
				results = [ results ]
			end

			debugMsg( 3, "#{results.size} events left after filtering." )
			return results.flatten
		end


	end #class IOEventStream
end #module MUES
