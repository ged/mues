#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end


### Log tests
class AARequireTestCase < MUES::TestCase

	def test_00Requires
		assert_nothing_raised { require 'mues/metaclass/Constants' }
		assert_instance_of Module, MUES::Metaclass

		assert_nothing_raised { require 'mues/metaclass/Attribute' }
		assert_instance_of Class, MUES::Metaclass::Attribute

		assert_nothing_raised { require 'mues/metaclass/Association' }
		assert_instance_of Class, MUES::Metaclass::Association

		assert_nothing_raised { require 'mues/metaclass/Operation' }
		assert_instance_of Class, MUES::Metaclass::Operation

		assert_nothing_raised { require 'mues/metaclass/MutatorOperation' }
		assert_instance_of Class, MUES::Metaclass::MutatorOperation

		assert_nothing_raised { require 'mues/metaclass/AccessorOperation' }
		assert_instance_of Class, MUES::Metaclass::AccessorOperation

		assert_nothing_raised { require 'mues/metaclass/Interface' }
		assert_instance_of Class, MUES::Metaclass::Interface

		assert_nothing_raised { require 'mues/metaclass/Namespace' }
		assert_instance_of Class, MUES::Metaclass::Namespace

		assert_nothing_raised { require 'mues/metaclass/Parameter' }
		assert_instance_of Class, MUES::Metaclass::Parameter

		assert_nothing_raised { require 'mues/metaclass/Class' }
		assert_instance_of Class, MUES::Metaclass::Class
	end

end # class RequireTestCase




