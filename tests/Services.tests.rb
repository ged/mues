#!/usr/bin/ruby

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
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



