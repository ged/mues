#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues/Log'

module MUES

	### Mock IO Object Class
	class MockIO < IO
		attr_accessor :fileno, :mode, :output, :opened

		def initialize( anInteger=0, mode="r" )
			@fileno = anInteger
			@mode = mode
			@opened = true
			@output = []
		end

		def close
			@opened = false
		end

		def closed?
			return ! @opened
		end

		def puts( stuff )
			@output.push stuff
		end

		def flush
			true
		end
	end

	### Log tests
	class LogTestCase < MUES::TestCase

		$Logfile = "testlog.#{$$}"
		$Levels = {
			"debug"		=> 0,
			"info"		=> 1,
			"notice"	=> 2,
			"error"		=> 3,
			"crit"		=> 4,
			"fatal"		=> 5
		}

		### Setup
		def set_up
			super
		end

		### Teardown
		def tear_down
			super
			if FileTest.exists?( $Logfile ) then
				File.delete( $Logfile )
			end
		end

		### TEST: Instantiate with no args (Tempfile log)
		def test_NewWithNoArgs
			log = Log.new
			assert_instance_of  Log, log 
			assert_equal log.level, $Levels["debug"] 
		end

		### TEST: Instantiate with filename arg
		def test_NewWithOneArg
			log = Log.new( $Logfile )
			assert_instance_of Log, log 
			assert_equal log.level, $Levels["debug"] 
		end

		### TEST: Instantiate with filename and level arg
		def test_NewWithTwoArgs
			log = Log.new( $Logfile, "info" )
			assert_instance_of Log, log 
			assert_equal log.level, $Levels["info"] 
		end

		### TEST: Test output
		def test_OutputAll
			io = MockIO.new
			log = Log.new( io, "debug" )

			assert_nothing_raised {
				$Levels.keys.each do |level|
					log.send( level, "Level: #{level}" )
				end
			}

			assert_equal io.output.size, $Levels.keys.size 
			$Levels.keys.each do |level|
				foundMatch = io.output.find {|outputLine| outputLine =~ /#{level}/}
				assert foundMatch, "No matching log line for the #{level} level."
			end
		end			
	end
end


