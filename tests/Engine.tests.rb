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
			$Engine = MUES::Engine.instance
		end

		def tear_down
			$Engine = nil
		end

		def test_s_instance
			assert_instance_of MUES::Engine, $Engine
			assert_equal $Engine, MUES::Engine.instance
		end

	end
end

