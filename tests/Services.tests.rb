#!/usr/bin/ruby

require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/Namespace.rb'
require 'mues/Service.rb'
require 'mues/Exceptions.rb'

### Adapter tests
module MUES

 	### Test the service class itself
	class ServiceClassTestCase < RUNIT::TestCase
		def test_00_GetServices
			service = nil
			assert_no_exception {
				service = MUES::Service.getService( "Test" )
			}
			assert_kind_of( MUES::Service, service )
		end
	end

	### Base service test
	class BaseServiceTestCase < RUNIT::TestCase
		def test_00_Instantiation
			### Shouldn't be able to instantiate, as it's an abstract class
			assert_exception( MUES::InstantiationError ) {
				instance = MUES::Service.new
			}
		end
	end

	### XML-RPC service tests
	class XmlRpcServiceTestCase < RUNIT::TestCase
	end


end


if $0 == __FILE__

	### Define a suite for all tests in this collection
	class TestAll
		def TestAll.suite
			suite = RUNIT::TestSuite.new
			ObjectSpace.each_object( Class ) {|klass|
				next unless klass < RUNIT::TestCase && klass.name =~ /^MUES::/
				suite.add_test( klass.suite )
			}
			suite
		end
	end

	### Run all the tests
	RUNIT::CUI::TestRunner.run( TestAll.suite )
end

