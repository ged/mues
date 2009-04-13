#!/usr/bin/ruby -w
#
# Unit test for the MUES::Logger class
# $Id$
#
# Copyright (c) 2003, 2004 RubyCrafters, LLC. Most rights reserved.
# 
# This work is licensed under the Creative Commons Attribution-ShareAlike
# License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/1.0/ or send a letter to Creative
# Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#
# 

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

require 'mues/object'
require 'mues/logger'

module MUES

	class TestObject < MUES::Object
		def debugLog( msg )
			self.log.debug( msg )
		end

		def infoLog( msg )
			self.log.info( msg )
		end

		def noticeLog( msg )
			self.log.notice( msg )
		end

		def warningLog( msg )
			self.log.warning( msg )
		end

		def errorLog( msg )
			self.log.error( msg )
		end

		def critLog( msg )
			self.log.crit( msg )
		end

		def alertLog( msg )
			self.log.alert( msg )
		end

		def emergLog( msg )
			self.log.emerg( msg )
		end
	end


	class TestOutputter < MUES::Logger::Outputter
		def initialize
			@outputCalls = []
			@output = ''
			super( "Testing outputter" )
		end

		attr_reader :outputCalls, :output

		def write( *args )
			@outputCalls << args
			super {|msg| @output << msg}
		end

		def clear
			@outputCalls = []
			@output = ''
		end
	end


	### Log tests
	class LogTestCase < MUES::TestCase

		LogLevels = [ :debug, :info, :notice, :warning, :error, :crit, :alert, :emerg ]

		def test_00_Loaded
			printTestHeader "Logger: Classes loaded"

			assert_instance_of Class, MUES::Logger
			[ :[], :global, :method_missing ].each {|sym|
				assert_respond_to MUES::Logger, sym
			}
		end

		def test_10_GlobalLogMethods
			printTestHeader "Logger: Global log methods"
			rval = nil
			testOp = TestOutputter::new

			assert_nothing_raised { rval = MUES::Logger.global }
			assert_instance_of MUES::Logger, rval
			assert_equal "", rval.name

			MUES::Logger.global.outputters << testOp

			LogLevels.each {|level|
				assert_nothing_raised { MUES::Logger.global.level = level }
				assert_nothing_raised { MUES::Logger.send(level, "test message") }
				assert_match( /test message/, testOp.output, "for output on #{level}" )

				testOp.clear

				unless level == :emerg
					assert_nothing_raised { MUES::Logger.global.level = :emerg }
					MUES::Logger.send(level, "test message")
					assert testOp.output.empty?, "Outputter expected to be empty"
				end
			}
		end

		def test_20_MuesObjectLogMethods
			printTestHeader "Logger: Object log methods"

			testObj = TestObject::new
			testOp = TestOutputter::new

			MUES::Logger.global.outputters = [ testOp ]

			LogLevels.each {|level|
				assert_nothing_raised { MUES::Logger.global.level = level }
				meth = "#{level.to_s}Log".intern
				assert_nothing_raised { testObj.send(meth, "test message") }
				assert_match( /test message/, testOp.output )
				testOp.clear
			}
		end


	end
end


