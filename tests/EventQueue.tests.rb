#!/usr/bin/ruby -w

require "runit/testcase"
require 'runit/cui/testrunner'

require "mues/EventQueue"
require "mues/Events"

module MUES

	### Mock event handler class
	class MockEventHandler < Object
		def initialize 
			@handledEvents = []
		end
		def handleEvent( e )
			@handledEvents.push e
		end
	end

	### Event queue tests
	class EventQueueTestCase < RUNIT::TestCase

		$MockHandler = nil
		$QueueObj = nil

		def setup
			$QueueObj = EventQueue.new
			# $QueueObj.debugLevel = 1
			$MockHandler = MockEventHandler.new
			DebugOutputEvent.RegisterHandlers( $MockHandler )
		end

		def teardown
			DebugOutputEvent.UnregisterHandlers( $MockHandler )
			$MockHandler = nil
			$QueueObj.shutdown if $QueueObj.running?

			if $0 == __FILE__
				threads = Thread.list
				#assert_equals( 1, threads.size )
				if threads.size > 1
					puts "\nThread status (Queue is #{ if $QueueObj.running? then \"running\" else \"not running\" end}):"
					puts "Supervisor thread: #{ $QueueObj.supervisor.id } (#{ $QueueObj.supervisor.status })" if
						$QueueObj.supervisor.is_a?( Thread )
					puts "Worker threads: #{ $QueueObj.workers.list.collect {|thr| thr.id}.join(',') }"
					puts "Idle worker threads: #{ $QueueObj.idleWorkers.list.collect {|thr| thr.id}.join(',') }"

					threads.each do |thr|
						next if thr == Thread.current || ! thr.alive?
						puts "\t#{thr.id} (#{thr.status})"
						thr.kill
					end
				end
			end
			
			$QueueObj = nil
		end
		
		def test_00_New
			assert_not_nil( $QueueObj )
			assert_instance_of( EventQueue, $QueueObj )
		end

		def test_01_StartStop
			assert_no_exception {
				$QueueObj.start
			}
			until $QueueObj.running? do sleep 0.1 end
			assert_no_exception {
				$QueueObj.shutdown
			}
		end

		def test_02_StopWithoutStart()
			assert_no_exception {
				$QueueObj.shutdown
			}
		end

		def test_03_StartWhileRunning()
			$QueueObj.debugLevel = 0
			$QueueObj.start
			assert_no_exception { $QueueObj.start }
			$QueueObj.shutdown
		end

		def test_04_QueueEvent
			assert_no_exception {
				ev = DebugOutputEvent.new( 1 )
				$QueueObj.enqueue( ev )
			}
		end

		def test_05_QueueWithoutArgs
			assert( ! $QueueObj.enqueue )
		end

	end

end


if $0 == __FILE__
	if ARGV.size == 0
		suite = MUES::EventQueueTestCase.suite
	else
		suite = RUNIT::TestSuite.new
		ARGV.each do |testmethod|
			suite.add_test(MUES::EventQueueTestCase.new(testmethod))
		end
	end
	RUNIT::CUI::TestRunner.run(suite)
end
