#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues/ClassLibrary'

### Log tests
module MUES
	class ClassLibraryTestCase < MUES::TestCase

		CLASSLIB_NAME = "testLibrary"

		@classLibrary = nil

		def set_up
			@classLibrary = MUES::ClassLibrary.new( CLASSLIB_NAME )
		end

		def tear_down
			@classLibrary = nil
		end

		def test_Instance
			assert_not_nil @classLibrary
			assert_instance_of MUES::ClassLibrary, @classLibrary
		end

		def test_Name
			assert_equal CLASSLIB_NAME, @classLibrary.name
		end

		def test_GetClassDefinition
			classCode = nil
			assert_nothing_raised {
				classCode = @classLibrary.getClassDefinition( "TestClass" )
			}
		end

		def test_GetClassAncestry
			heir = nil
			assert_nothing_raised {
				heir = @classLibrary.getClassAncestry( "TestClass" )
			}
		end

	end
end


