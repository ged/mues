#!/usr/bin/ruby -w

require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/ClassLibrary'

### Log tests
module MUES
	class ClassLibraryTestCase < RUNIT::TestCase

		CLASSLIB_NAME = "testLibrary"

		@classLibrary = nil

		def setup
			@classLibrary = MUES::ClassLibrary.new( CLASSLIB_NAME )
		end

		def teardown
			@classLibrary = nil
		end

		def test_Instance
			assert_not_nil( @classLibrary )
			assert_instance_of( MUES::ClassLibrary, @classLibrary )
		end

		def test_Name
			assert_equals( CLASSLIB_NAME, @classLibrary.name )
		end

		def test_GetClassDefinition
			classCode = nil
			assert_no_exception {
				classCode = @classLibrary.getClassDefinition( "TestClass" )
			}
		end

		def test_GetClassAncestry
			heir = nil
			assert_no_exception {
				heir = @classLibrary.getClassAncestry( "TestClass" )
			}
		end

	end
end


if $0 == __FILE__
	if ARGV.size == 0
		suite = MUES::ClassLibraryTestCase.suite
	else
		suite = RUNIT::TestSuite.new
		ARGV.each do |testmethod|
			suite.add_test(MUES::ClassLibraryTestCase.new(testmethod))
		end
	end
	RUNIT::CUI::TestRunner.run(suite)
end

