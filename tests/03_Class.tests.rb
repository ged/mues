#!/usr/bin/ruby -w

require 'metaclass/Constants'
require 'metaclass/Class'

require 'test/unit'

### Log tests
module Metaclass
	class ClassTestCase < Test::Unit::TestCase

		### Test instantiation with various arguments
		def test_Instantiate
			parentObj = nil
			obj = nil

			# 0-arg -- should raise an exception
			assert_raises( ArgumentError ) { Metaclass::Class.new }
			
			# 1-arg
			assert_nothing_raised { obj = Metaclass::Class.new("Tester") }
			assert_instance_of Metaclass::Class, obj

			# 2-arg, illegal second arg
			assert_raises( TypeError ) { Metaclass::Class.new("Tester", "notAClass") }

			# 2-arg, legal second arg
			parentObj = Metaclass::Class.new( "Super" )
			assert_nothing_raised { obj = Metaclass::Class.new("Sub", parentObj) }
		end

		def test_Accessors
			parentObj = Metaclass::Class.new("Parent")
			obj = Metaclass::Class.new("Tester", parentObj)

			assert_equal "Tester", obj.name
			assert_instance_of Hash, obj.operations
			assert_instance_of Hash, obj.classOperations
			assert_instance_of Hash, obj.attributes
			assert_instance_of Hash, obj.classAttributes
			assert_instance_of Array, obj.interfaces
			assert_same parentObj, obj.superclass
		end



	end # class ClassTestCase
end # module Metaclass

