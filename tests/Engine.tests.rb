#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues/Engine.rb'

module MUES
	class EngineTestCase < MUES::TestCase

		def set_up
			@engine = MUES::Engine.instance
		end

		def tear_down
			$Engine = nil
		end

		def test_00_Instantiate
			assert_instance_of MUES::Engine, @engine
			assert_equal @engine, MUES::Engine.instance
		end

	end
end

