#!/usr/bin/ruby -w

require 'metaclass/Constants'
require 'metaclass/Association'

require 'test/unit'

### Log tests
module Metaclass

	class MockAssnSubclass < Metaclass::Association
		public_class_method :new
	end

	class AssociationTestCase < Test::Unit::TestCase

		### Test instantiation with various arguments
		def test_Instantiate
			assert_raises( NoMethodError ) { Metaclass::Association.new }
		end

		### Test subclass instantiation
		def test_SubclassInstantiation
			obj = nil

			# No-arg (should raise an ArgumentError)
			assert_raises( ArgumentError ) { Metaclass::MockAssnSubclass.new }

			# One-arg. Test inherited initializer and accessor
			assert_nothing_raised { obj = Metaclass::MockAssnSubclass.new("thename") }
			assert_equal "thename", obj.name
		end

	end # class AssociationTestCase
end # module Metaclass

