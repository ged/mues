#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues'
require 'mues/Exceptions'
require 'thread'


class ResponseTestObject
	def oneMethod
		return true
	end
	def twoMethod
		return true
	end
	def redMethod
		return true
	end
	def blueMethod
		return true
	end
end

class LibraryFunctionsTestCase < MUES::TestCase

	### Test instantiation with various arguments
	def test_checkSafeLevel

		# Run this in a thread so we can reduce our $SAFE temporarily
		t = Thread.new {
			$SAFE = 3
			checkSafeLevel()
			raise StandardError, "Failed."
		}

		assert_raises( SecurityError ) { t.join }
		assert_nothing_raised { checkSafeLevel() }
	end

	def test_checkType
		assert_raises( TypeError ) {
			checkType( "a string", Numeric )
		}
		assert_raises( TypeError ) {
			checkType( "a string", Numeric, Hash )
		}
		assert_nothing_raised {
			checkType( "a string", Numeric, Hash, String )
		}
	end

	def test_checkEachType
		things = [ "a string", 5, {'a' => 'test', 'hash' => 'object'} ]


		assert_raises( TypeError ) {
			checkEachType( things, Numeric )
		}
		assert_raises( TypeError ) {
			checkEachType( things, Numeric, Hash )
		}
		assert_nothing_raised {
			checkEachType( things, Numeric, Hash, String )
		}
	end


	def test_checkResponse
		testObj = ResponseTestObject::new

		assert_nothing_raised {
			checkResponse( testObj, :oneMethod )
		}
		assert_nothing_raised {
			checkResponse( testObj, :oneMethod, :twoMethod )
		}
		assert_nothing_raised {
			checkResponse( testObj, :oneMethod, :twoMethod, :redMethod )
		}
		assert_nothing_raised {
			checkResponse( testObj, :oneMethod, :twoMethod, :redMethod, :blueMethod )
		}
		assert_raises( TypeError ) {
			checkResponse( testObj, :oneMethod, :twoMethod, :redMethod, :blueMethod, :fooMethod )
		}
	end

	def test_checkEachResponse
		testObjs = []
		10.times { testObjs << ResponseTestObject::new }

		assert_nothing_raised {
			checkEachResponse( testObjs, :oneMethod )
		}
		assert_nothing_raised {
			checkEachResponse( testObjs, :oneMethod, :twoMethod )
		}
		assert_nothing_raised {
			checkEachResponse( testObjs, :oneMethod, :twoMethod, :redMethod )
		}
		assert_nothing_raised {
			checkEachResponse( testObjs, :oneMethod, :twoMethod, :redMethod, :blueMethod )
		}
		assert_raises( TypeError ) {
			checkEachResponse( testObjs, :oneMethod, :twoMethod, :redMethod, :blueMethod, :fooMethod )
		}
		assert_raises( TypeError ) {
			checkEachResponse( testObjs + ["a string"], :oneMethod )
		}
	end

	def test_abstractDeclaration
		anonClass = nil
		anonSubClass = nil
		testObj = nil

		# Define a test class with one virtual method
		assert_nothing_raised {
			anonClass = Class::new {|klass|
				abstract :foo
			}
		}

		assert_instance_of Class, anonClass
		assert_nothing_raised { testObj = anonClass.new }
		assert_raises( MUES::VirtualMethodError ) { testObj.foo }

		# Now override the virtual method in a subclass and test again.
		assert_nothing_raised {
			anonSubClass = Class::new( anonClass ) {
				class_eval %Q{
					def foo
						return true
					end
				}
			}
		}

		assert_instance_of Class, anonSubClass
		assert_nothing_raised { testObj = anonSubClass.new }
		assert_nothing_raised { testObj.foo }
	end



end # class LibraryFunctionsTestCase

