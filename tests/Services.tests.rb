#!/usr/bin/ruby

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues/Service.rb'
require 'mues/Exceptions.rb'

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

		def set_up
			@mockService = MockService.new
		end

		def tear_down
			@mockService = nil
		end

		def test_New
			assert_raises( InstantiationError ) {
				Service.new
			}
		end

		def test_DerivedNew
			assert_kind_of( Service, @mockService )
		end

		def test_GetServices
			service = nil
			assert_nothing_raised {
				service = MUES::Service.getService( "Mock" )
			}
			# assert_kind_of MUES::Service, service
		end
	end

	### Base service test
	class BaseServiceTestCase < MUES::TestCase
		def test_00_Instantiation
			### Shouldn't be able to instantiate, as it's an abstract class
			assert_raises( MUES::InstantiationError ) {
				instance = MUES::Service.new
			}
		end
	end

	### XML-RPC service tests
	class XmlRpcServiceTestCase < MUES::TestCase
	end


end



