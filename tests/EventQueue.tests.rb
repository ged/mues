#!/usr/bin/ruby -w

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
end

require "mues/EventQueue"
require "mues/Events"


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
			@queueObj = EventQueue.new
			@mockHandler = MockEventHandler.new
			@mockHandler.activate

			begin
				DebugOutputEvent.RegisterHandlers( @mockHandler )
			rescue
				puts @mockHandler.callTrace.join("\n")
			end
		end

		def teardown
			DebugOutputEvent.UnregisterHandlers( @mockHandler )
			@mockHandler = nil
			@queueObj.shutdown if @queueObj.running?

			if $0 == __FILE__
				threads = Thread.list
				#assert_equal( 1, threads.size )
				if threads.size > 1
					puts "\nThread status (Queue is #{ if @queueObj.running? then %{running} else %{not running} end}):"
					puts "Supervisor thread: #{ @queueObj.supervisor.id } (#{ @queueObj.supervisor.status })" if
						@queueObj.supervisor.is_a?( Thread )
					puts "Worker threads: #{ @queueObj.workers.list.collect {|thr| thr.id}.join(',') }"
					puts "Idle worker threads: #{ @queueObj.idleWorkers.list.collect {|thr| thr.id}.join(',') }"

					threads.each do |thr|
						next if thr == Thread.current || ! thr.alive?
						puts "\t#{thr.id} (#{thr.status})"
						thr.kill
					end
				end
			end
			
			@queueObj = nil
		end
		
		def test_00_New
			assert_not_nil @queueObj
			assert_instance_of MUES::EventQueue, @queueObj
		end

		def test_01_StartStop
			mockEngine = Test::Unit::MockObject( MUES::Engine ).new

			assert_nothing_raised { @queueObj.start(mockEngine) }
			until @queueObj.running? do sleep 0.1 end
			assert_nothing_raised { @queueObj.shutdown }
		end

		def test_02_StopWithoutStart()
			assert_nothing_raised { @queueObj.shutdown }
		end

		def test_03_StartWhileRunning()
			mockEngine = Test::Unit::MockObject( MUES::Engine ).new
			@queueObj.debugLevel = 0
			@queueObj.start( mockEngine )
			assert_nothing_raised { @queueObj.start(mockEngine) }
			@queueObj.shutdown
		end

		def test_04_QueueEvent
			assert_nothing_raised {
				ev = DebugOutputEvent.new( 1 )
				@queueObj.enqueue( ev )
			}
		end

		def test_05_QueueWithoutArgs
			assert ! @queueObj.enqueue
		end

	end

end

