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

require 'mues/log'
require 'mues/object'

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

		def warnLog( msg )
			self.log.warn( msg )
		end

		def errorLog( msg )
			self.log.error( msg )
		end

		def critLog( msg )
			self.log.crit( msg )
		end

		def fatalLog( msg )
			self.log.fatal( msg )
		end

	end


	### Log tests
	class LogTestCase < MUES::TestCase

		LogLevels = [ :debug, :info, :notice, :warn, :error, :crit, :fatal ]

		def test_00_Loaded
			assert_instance_of Class, MUES::Log
			[ :configure, :mueslogger, :method_missing ].each {|sym|
				assert_respond_to MUES::Log, sym
			}
			assert_instance_of Array, MUES::Log::LogLevels
			assert_equal LogLevels, MUES::Log::LogLevels
		end

		def test_10_GlobalLogMethods
			LogLevels.each {|level|
				assert_nothing_raised { MUES::Log.send(level, "test message") }
			}
		end

		def test_20_MuesObjectLogMethods
			testObj = TestObject::new

			LogLevels.each {|level|
				meth = "#{level.to_s}Log".intern
				assert_nothing_raised { testObj.send(meth, "test message") }
			}
		end


	end
end


