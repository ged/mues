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

require 'mues/eventqueue'
require 'mues/events'


module MUES

	### Mock event handler class
	class MockEventHandler < Test::Unit::MockObject( MUES::Object )
		def initialize 
			super
			@handledEvents = []
		end
		def handleEvent( e )
			@handledEvents.push e
		end
	end


	### Event queue tests
	class EventQueueTestCase < MUES::TestCase

		def setup
			@mockHandler = MockEventHandler::new
			@mockHandler.activate

			begin
				DebugOutputEvent::registerHandlers( @mockHandler )
			rescue
				puts @mockHandler.callTrace.join("\n")
			end
			super
		end

		def teardown
			super
			DebugOutputEvent::unregisterHandlers( @mockHandler )
			@mockHandler = nil
		end

		# Testing consequence-handler method
		def consequenceHandler( *ev )
		end


		#############################################################
		###	T E S T S
		#############################################################

		def test_00_Classes
			printTestHeader "EventQueue: Classes"
			assert_instance_of Class, MUES::EventQueue
		end


		def test_10_Instantiation
			printTestHeader "EventQueue: Instantiation"
			rval = nil

			assert_nothing_raised { rval = MUES::EventQueue::new }
			assert_instance_of MUES::EventQueue, rval

			addSetupBlock {
				@queue = MUES::EventQueue::new
				debugMsg "Setup queue %p" % @queue
			}
			addTeardownBlock {
				debugMsg "Tearing down queue %p" % @queue
				@queue = nil
			}
		end


		def test_20_StartStop
			printTestHeader "EventQueue: Start/Stop (no consequence handler)"

			assert_nothing_raised { @queue.start }
			until @queue.running? do sleep 0.1 end
			assert_nothing_raised { @queue.shutdown }
		end

		def test_21_StartStopWithBlock
			printTestHeader "EventQueue: Start/Stop (iterator consequence handler)"

			assert_nothing_raised {
				@queue.start {|*ev| ev }
			}
			until @queue.running? do sleep 0.1 end
			assert_nothing_raised { @queue.shutdown }
		end

		def test_22_StartStopWithMethod
			printTestHeader "EventQueue: Start/Stop (method consequence handler)"

			assert_nothing_raised {
				@queue.start( &method(:consequenceHandler) )
			}
			until @queue.running? do sleep 0.1 end
			assert_nothing_raised { @queue.shutdown }
		end

		def test_30_ShutdownWithoutStart()
			printTestHeader "EventQueue: Shutdown without start"
			assert_nothing_raised { @queue.shutdown }
		end

		def test_40_StartWhileRunning()
			printTestHeader "EventQueue: Start while running"
			mockEngine = Test::Unit::MockObject( MUES::Engine ).new
			@queue.debugLevel = 0
			@queue.start
			assert_nothing_raised { @queue.start }
			@queue.shutdown
		end

		def test_50_QueueEvent
			printTestHeader "EventQueue: Queue Event"
			assert_nothing_raised {
				ev = DebugOutputEvent.new( 1 )
				@queue.enqueue( ev )
			}
		end

		def test_60_QueueWithoutArgs
			printTestHeader "EventQueue: Queue without args"
			assert ! @queue.enqueue
		end

	end

end

