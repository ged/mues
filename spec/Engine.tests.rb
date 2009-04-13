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

