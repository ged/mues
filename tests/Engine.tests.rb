#!/usr/bin/ruby -w

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
end

require 'mues/engine.rb'

module MUES
	class EngineTestCase < MUES::TestCase


		#############################################################
		###	T E S T S
		#############################################################

		# Test Engine class
		def test_00_Class
			printTestHeader "Engine: Class"
			assert_instance_of Class, MUES::Engine
		end


		# Test instantiation and singleton-ness
		def test_10_Instantiation
			printTestHeader "Engine: Instantiation/Singleton"
			rval = nil
			
			assert_nothing_raised {
				rval = MUES::Engine::instance
			}

			assert_instance_of MUES::Engine, rval
			assert_same MUES::Engine::instance, rval
		end
	end
end

