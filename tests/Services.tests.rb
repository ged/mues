#!/usr/bin/ruby

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

require 'mues/service.rb'
require 'mues/exceptions.rb'

### Adapter tests
module MUES

	### Mock service object class
	class MockService < Service
		def initialize
			super( "mock", "This is a mock service for testing." )
		end
	end


 	### Test the service class itself
	class ServiceClassTestCase < MUES::TestCase
		def test_00_Instantiate
			assert_raises( InstantiationError ) { MUES::Service.new }

			service = MUES::Service::create( "Mock" )
			assert_kind_of( MUES::Service, service )
		end
	end

end



