#!/usr/bin/ruby -w

begin
	require 'muesunittest'
rescue
	require '../muesunittest'
end

require 'metaclasses'

# Mock object
class MockAssnSubclass < Metaclass::Association
	public_class_method :new
end

class AssociationTestCase < MUES::TestCase

	### Test instantiation with various arguments
	def test_00Instantiate
		assert_raises( NoMethodError ) { Metaclass::Association.new }
	end

	### Test subclass instantiation
	def test_01SubclassInstantiation
		obj = nil

		# No-arg (should raise an ArgumentError)
		assert_raises( ArgumentError ) { MockAssnSubclass.new }

		# One-arg. Test inherited initializer and accessor
		assert_nothing_raised { obj = MockAssnSubclass.new("thename") }
		assert_equal "thename", obj.name
	end

end # class AssociationTestCase

