#!/usr/bin/ruby -w

require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/ObjectStore'

### Log tests
module MUES
	class TestObjectStore < RUNIT::TestCase

		def setup
			super
		end

		def teardown
			super
		end

		def test_LoadAdapters
			assert MUES::ObjectStore._loadAdapters
		end

		def test_HasAdapter
			assert MUES::ObjectStore._hasAdapter?( "Dummy" ) 
		end

		def test_GetAdapter
			a = MUES::ObjectStore._getAdapter( "Dummy", "test", "host", "user", "password" )
			assert_instance_of MUES::ObjectStore::DummyAdapter, a
			assert_equals( "test", a.db )
			assert_equals( "host", a.host )
			assert_equals( "user", a.user )
			assert_equals( "password", a.password )
		end
	end
end

if $0 == __FILE__
	if ARGV.size == 0
		suite = MUES::TestObjectStore.suite
	else
		suite = RUNIT::TestSuite.new
		ARGV.each do |testmethod|
			suite.add_test(MUES::TestObjectStore.new(testmethod))
		end
	end
	RUNIT::CUI::TestRunner.run(suite)
end

