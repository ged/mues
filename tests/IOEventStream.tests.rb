#!/usr/bin/ruby -w

require "runit/testcase"
require 'runit/cui/testrunner'

require "thread"

require "mues/IOEventStream"
require "mues/IOEventFilters"

module MUES

	### Subclass of the stream class that lets us see protected instance variables
	class TestingStream < IOEventStream
		attr_reader :notifyingInputObjects, :notifyingOutputObjects, :streamThread
	end

	### Mock event filter class
	class MockFilter < IOEventFilter
		DefaultSortPosition = 501

		attr_accessor :name, :inputEvents, :outputEvents, :startArg, :stopArg

		def initialize( name, *args )
			super( *args )
			@name			= name
			@inputEvents	= []
			@outputEvents	= []
			@startArg		= nil
			@stopArg		= nil
		end

		def start( arg )
			@startArg = arg
		end

		def shutdown( arg )
			@stopArg = arg
		end

		def handleInputEvents( *events )
			myEvents = events.select {|e| e.data =~ @name}
			@inputEvents.push( myEvents )
			@inputEvents.flatten!
			events -= myEvents
			return events
		end

		def handleOutputEvents( *events )
			myEvents = events.select {|e| e.data =~ @name}
			@outputEvents.push( myEvents )
			@outputEvents.flatten!
			events -= myEvents
			return events
		end

		def to_s
			"<MockFilter '#{@name}'>"
		end

		def inspect
			to_s()
		end

	end

	### Mock event filter subclass
	class SubMockFilter < MockFilter
		DefaultSortPosition = 502
	end

	### Mock IOEvent classes
	class MockInputEvent < InputEvent
	end
	class MockOutputEvent < OutputEvent
	end

	### Stream test case
	class IOEventStreamTestCase < RUNIT::TestCase

		@stream = nil

		### Test case setup method
		def setup
			@stream = TestingStream.new
		end

		### Test case teardown method
		def teardown
			@stream = nil
		end

		### Test to be sure instantiation works, and that the object has all the
		### expected attributes in the state we expect them
		def test_00_Instantiation
			assert_kind_of( MUES::IOEventStream, @stream )

			# Filters
			assert_instance_of( Array, @stream.filters )
			assert_equals( 2, @stream.filters.length )
			@stream.filters.each {|f|
				assert_kind_of( MUES::IOEventFilter, f )
			}

			# State
			assert_equals( MUES::IOEventStream::RUNNING, @stream.state )
			
			# Thread
			assert_instance_of( Thread, @stream.streamThread )
			assert_match( %r{IOEventStream thread}, @stream.streamThread.desc )
		end

		### Test adding and removing filters
		def test_01_AddRemoveFilters
			filter = MockFilter.new( "first filter" )
			laterFilter = MockFilter.new( "second filter", 450 )

			# Can add
			assert_no_exception {
				@stream.addFilters( filter, laterFilter )
			}

			# Cannot add non-filter
			assert_exception( TypeError ) {
				@stream.addFilters( "A String which is decidedly not a filter" )
			}
			
			# Filters are added
			assert_equals( 4, @stream.filters.length )
			assert @stream.filters.member?( filter )
			assert @stream.filters.member?( laterFilter )

			# Filters were started when they were added
			assert_not_nil( filter.startArg )
			assert_same( @stream, filter.startArg )

			# Removing a non-existant filter doesn't change the stream and
			# doesn't error
			removedFilters = nil
			assert_no_exception {
				removedFilters = @stream.removeFilters( MockFilter.new("Remove tester") )
			}
			assert_equals( 0, removedFilters.length )
			assert_equals( 4, @stream.filters.length )
			assert @stream.filters.member?( filter )
			assert @stream.filters.member?( laterFilter )

			# Removing an added filter removes the correct one
			removedFilters = nil
			assert_no_exception {
				removedFilters = @stream.removeFilters( filter )
			}
			assert_equals( 1, removedFilters.length )
			assert_equals( 3, @stream.filters.length )
			assert_same( removedFilters[0], filter )
			assert( ! @stream.filters.member?(filter) )
			assert @stream.filters.member?( laterFilter )
			
		end


		### Test persistance of default filters
		def test_02_DefaultFilters
			removedFilters = nil
			assert_no_exception {
				removedFilters = @stream.removeFiltersOfType( MUES::IOEventFilter )
			}
			assert_equals( 0, removedFilters.length )
		end

		### Remove filters by type
		def test_03_RemoveFiltersByType

			# Setup
			removedFilters = nil
			filter1 = MockFilter.new( "filter1" )
			filter2 = SubMockFilter.new( "filter2" )
			filter3 = SubMockFilter.new( "filter3" )
			@stream.addFilters( filter1, filter2, filter3 )

			# Make sure we can remove filters by type
			assert_no_exception {
				removedFilters = @stream.removeFiltersOfType( SubMockFilter )
			}
			assert_equals( 2, removedFilters.length )
			assert_equals( 3, @stream.filters.length )

			# Re-add the removed filters
			@stream.addFilters( *removedFilters )

			# Make sure we can remove filters by parent type, too
			removedFilters = nil
			assert_no_exception {
				removedFilters = @stream.removeFiltersOfType( MockFilter )
			}
			assert_equals( 3, removedFilters.length )
			assert_equals( 2, @stream.filters.length )
		end

		### Test stream pausing
		def test_04_PauseStream
			assert_no_exception {
				@stream.pause
			}

			assert @stream.paused

			assert_no_exception {
				@stream.unpause
			}
		end

		### Test IO event queuing
		def test_05_AddEvents

			# Setup
			inEvent = MockInputEvent.new( "Some input" )
			outEvent = MockOutputEvent.new( "Some output" )
			
			# Pause the stream so we can catch events before they're processed
			@stream.pause

			# Make sure we can't queue things other than events
			assert_exception( UnhandledEventError ) {
				@stream.addEvents( "Something most decidedly not an IOEvent" )
			}

			# Make sure we can't queue other kinds of events
			assert_exception( UnhandledEventError ) {
				@stream.addEvents( MUES::LogEvent.new("something") )
			}

			# Now add our events and make sure they're queued in the right queues
			assert_no_exception {
				@stream.addEvents( inEvent, outEvent )
			}
			assert_equals( 1, @stream.outputEvents.length )
			assert_same( @stream.outputEvents[0], outEvent )
			assert_equals( 1, @stream.inputEvents.length )
			assert_same( @stream.inputEvents[0], inEvent )
			
		end

		### Test IO event de-queueing
		def test_06_FetchEvents

			# Setup
			inEvent = MockInputEvent.new( "Some input" )
			outEvent = MockOutputEvent.new( "Some output" )
			
			# Pause the stream so we can catch events before they're processed
			@stream.pause

			# Make sure dequeuing from input without any events isn't an error
			assert_no_exception {
				@stream.fetchInputEvents()
			}

			# Make sure dequeuing from output without any events isn't an error
			assert_no_exception {
				@stream.fetchOutputEvents()
			}

			@stream.addEvents( inEvent, outEvent )

			# Check removing via the fetchInputEvents method
			removedEvents = nil
			assert_no_exception {
				removedEvents = @stream.fetchInputEvents
			}
			assert_equals( 1, removedEvents.length )
			assert_same( removedEvents[0], inEvent )

			# Now do the same for the fetchOutputEvents method
			removedEvents = nil
			assert_no_exception {
				removedEvents = @stream.fetchOutputEvents
			}
			assert_equals( 1, removedEvents.length )
			assert_same( removedEvents[0], outEvent )

		end

		### Test IO event handling
		def test_07_EventHandling

			# Set up objects for testing
			outFilter = MockFilter.new( "output", 300 )
			inFilter = MockFilter.new( "input", 700 )
			inEvent = InputEvent.new( "input" )
			outEvent = OutputEvent.new( "output" )

			# Add the testing filters
			# @stream.debugLevel = 5
			@stream.addFilters( inFilter, outFilter )

			# Now send the test events through
			@stream.addEvents( inEvent, outEvent )

			# Wait for the stream's thread to handle the events and become idle again
			Thread.pass until @stream.notifyingInputObjects.empty? && @stream.notifyingOutputObjects.empty?
			Thread.pass until @stream.idle

			# Check to see if they got sent through correctly
			assert_equal( 1, inFilter.inputEvents.length )
			assert_same( inEvent, inFilter.inputEvents[0] )
			assert_equal( 1, outFilter.outputEvents.length )
			assert_same( outEvent, outFilter.outputEvents[0] )
		end

	end

end


if $0 == __FILE__
	if ARGV.size == 0
		suite = MUES::IOEventStreamTestCase.suite
	else
		suite = RUNIT::TestSuite.new
		ARGV.each do |testmethod|
			suite.add_test(MUES::IOEventStreamTestCase.new(testmethod))
		end
	end
	RUNIT::CUI::TestRunner.run(suite)
end