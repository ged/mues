#!/usr/bin/ruby -w

require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/ClassLibrary'

### Log tests
module MUES
	class TestClassLibrary < RUNIT::TestCase

		CLASSLIB_NAME = "testLibrary"

		def setup
			$ClassLibrary = MUES::ClassLibrary.new( CLASSLIB_NAME )
		end

		def teardown
			$ClassLibrary = nil
		end

		def test_Instance
			assert_not_nil( $ClassLibrary )
			assert_instance_of( MUES::ClassLibrary, $ClassLibrary )
		end

		def test_Name
			assert_equals( CLASSLIB_NAME, $ClassLibrary.name )
		end

		def test_GetClassDefinition
			classCode = nil
			assert_no_exception {
				classCode = $ClassLibrary.getClassDefinition( "TestClass" )
			}
		end

		def test_GetClassAncestry
			heir = nil
			assert_no_exception {
				heir = $ClassLibrary.getClassAncestry( "TestClass" )
			}
		end

	end
end


if $0 == __FILE__
	if ARGV.size == 0
		suite = MUES::TestClassLibrary.suite
	else
		suite = RUNIT::TestSuite.new
		ARGV.each do |testmethod|
			suite.add_test(MUES::TestClassLibrary.new(testmethod))
		end
	end
	RUNIT::CUI::TestRunner.run(suite)
end

