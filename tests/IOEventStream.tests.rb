#!/usr/bin/ruby -w

unless defined? MUES && defined? MUES::TestCase
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )

	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/ext" unless
		$LOAD_PATH.include?( "#{basedir}/ext" )
	$LOAD_PATH.unshift "#{basedir}/tests" unless
		$LOAD_PATH.include?( "#{basedir}/tests" )

	require 'muestestcase'
end

require "thread"

require 'mues/ioeventstream'
require 'mues/ioeventfilters'

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
			myEvents = events.select {|e| e.data =~ /#@name/}
			@inputEvents.push( myEvents )
			@inputEvents.flatten!
			events -= myEvents
			return events
		end

		def handleOutputEvents( *events )
			myEvents = events.select {|e| e.data =~ /#@name/}
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

	### Mock event filter subclass that returns another filter as results of
	### input/output event handlers.
	class FilterCreatingFilter < MockFilter
		DefaultSortPosition = 505

		def handleInputEvents( *events )
			events = [ SubMockFilter::new(455) ] unless events.empty?
			return events
		end

		def handleOutputEvents( *events )
			events = [ SubMockFilter::new(555) ] unless events.empty?
			return events
		end
	end

	### Mock IOEvent classes
	class MockInputEvent < InputEvent
	end
	class MockOutputEvent < OutputEvent
	end



	### Stream test case
	class IOEventStreamTestCase < MUES::TestCase

		### Test case set_up method
		def setup
			@stream = TestingStream::new
		end

		def teardown
			@stream.shutdown
		end


		#############################################################
		###	T E S T S
		#############################################################

		### Test to be sure instantiation works, and that the object has all the
		### expected attributes in the state we expect them
		def test_00_Instantiation
			assert_kind_of MUES::IOEventStream, @stream

			# Filters
			assert_instance_of Array, @stream.filters
			assert_equal 2, @stream.filters.length
			@stream.filters.each {|f|
				assert_kind_of MUES::IOEventFilter, f
			}

			# State
			assert_equal MUES::IOEventStream::RUNNING, @stream.state
			
			# Thread
			assert_instance_of Thread, @stream.streamThread
			assert_match %r{IOEventStream thread}, @stream.streamThread.desc
		end


		### Test adding and removing filters
		def test_01_AddRemoveFilters
			filter = MockFilter.new( "first filter" )
			laterFilter = MockFilter.new( "second filter", 450 )

			# Can add
			assert_nothing_raised {
				@stream.addFilters( filter, laterFilter )
			}

			# Cannot add non-filter
			assert_raises( TypeError ) {
				@stream.addFilters( "A String which is decidedly not a filter" )
			}
			
			# Filters are added
			assert_equal  4, @stream.filters.length 
			assert @stream.filters.member?( filter )
			assert @stream.filters.member?( laterFilter )

			# Filters were started when they were added
			assert_not_nil  filter.startArg 
			assert_same  @stream, filter.startArg 

			# Removing a non-existant filter doesn't change the stream and
			# doesn't error
			assert_nothing_raised {
				@stream.removeFilters( MockFilter.new("Remove tester") )
			}
			assert_equal  4, @stream.filters.length 
			assert @stream.filters.member?( filter )
			assert @stream.filters.member?( laterFilter )

			# Removing an added filter removes the correct one
			assert_nothing_raised {
				@stream.removeFilters( filter )
			}
			assert_equal  3, @stream.filters.length 
			assert( ! @stream.filters.member?(filter) )
			assert @stream.filters.member?( laterFilter )
			
		end


		### Test persistance of default filters
		def test_02_DefaultFilters
			assert_nothing_raised {
				@stream.removeFiltersOfType( MUES::IOEventFilter )
			}
			assert_equal 2, @stream.filters.length
		end


		### Remove filters by type
		def test_03_RemoveFiltersByType

			# Setup
			filter1 = MockFilter.new( "filter1" )
			filter2 = SubMockFilter.new( "filter2" )
			filter3 = SubMockFilter.new( "filter3" )
			@stream.addFilters( filter1, filter2, filter3 )

			# Make sure we can remove filters by type
			assert_nothing_raised {
				@stream.removeFiltersOfType( SubMockFilter )
			}
			assert_equal  3, @stream.filters.length 

			# Re-add the removed filters
			@stream.addFilters( filter2, filter3 )

			# Make sure we can remove filters by parent type, too
			assert_nothing_raised {
				@stream.removeFiltersOfType( MockFilter )
			}
			assert_equal  2, @stream.filters.length 
		end

		### Test stream pausing
		def test_04_PauseStream
			assert_nothing_raised { @stream.pause }
			assert @stream.paused
			assert_nothing_raised { @stream.unpause }
		end

		### Test IO event queuing
		def test_05_AddEvents

			# Setup
			inEvent = MockInputEvent.new( "Some input" )
			outEvent = MockOutputEvent.new( "Some output" )
			
			# Pause the stream so we can catch events before they're processed
			@stream.pause

			# Make sure we can't queue things other than events
			assert_raises( UnhandledEventError ) {
				@stream.addEvents( "Something most decidedly not an IOEvent" )
			}

			# Make sure we can't queue other kinds of events
			assert_raises( UnhandledEventError ) {
				@stream.addEvents( MUES::LogEvent.new("something") )
			}

			# Now add our events and make sure they're queued in the right queues
			assert_nothing_raised {
				@stream.addEvents( inEvent, outEvent )
			}
			assert_equal  1, @stream.outputEvents.length 
			assert_same  @stream.outputEvents[0], outEvent 
			assert_equal  1, @stream.inputEvents.length 
			assert_same  @stream.inputEvents[0], inEvent 
			
		end

		### Test IO event de-queueing
		def test_06_FetchEvents

			# Setup
			inEvent = MockInputEvent.new( "Some input" )
			outEvent = MockOutputEvent.new( "Some output" )
			
			# Pause the stream so we can catch events before they're processed
			@stream.pause

			# Make sure dequeuing from input without any events isn't an error
			assert_nothing_raised {
				@stream.fetchInputEvents()
			}

			# Make sure dequeuing from output without any events isn't an error
			assert_nothing_raised {
				@stream.fetchOutputEvents()
			}

			@stream.addEvents( inEvent, outEvent )

			# Check removing via the fetchInputEvents method
			removedEvents = nil
			assert_nothing_raised {
				removedEvents = @stream.fetchInputEvents
			}
			assert_equal  1, removedEvents.length 
			assert_same  removedEvents[0], inEvent 

			# Now do the same for the fetchOutputEvents method
			removedEvents = nil
			assert_nothing_raised {
				removedEvents = @stream.fetchOutputEvents
			}
			assert_equal  1, removedEvents.length 
			assert_same  removedEvents[0], outEvent 

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
			assert_equal  1, inFilter.inputEvents.length 
			assert_same  inEvent, inFilter.inputEvents[0] 
			assert_equal  1, outFilter.outputEvents.length 
			assert_same  outEvent, outFilter.outputEvents[0] 
		end

		### Test Filter event-handler results
		def test_08_FilterResult
			@stream.debugLevel = 5

			filterFilter = FilterCreatingFilter::new( "fcf", 515 )
			@stream.addFilters( filterFilter )

			assert_equal 3, @stream.filters.length

			inEvent = InputEvent.new( "input" )
			assert_nothing_raised { @stream.addEvents(inEvent) }
			Thread.pass until @stream.notifyingInputObjects.empty? && @stream.notifyingOutputObjects.empty?
			Thread.pass until @stream.idle

			assert_equal 4, @stream.filters.length

			outEvent = OutputEvent.new( "output" )
			assert_nothing_raised { @stream.addEvents(outEvent) }
			Thread.pass until @stream.notifyingInputObjects.empty? && @stream.notifyingOutputObjects.empty?
			Thread.pass until @stream.idle

			assert_equal 5, @stream.filters.length
		end

	end

end

