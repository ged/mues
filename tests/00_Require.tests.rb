#!/usr/bin/ruby -w

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
end


### Log tests
class AARequireTestCase < MUES::TestCase

	def test_00Requires
		assert_nothing_raised { require 'mues/metaclass/constants' }
		assert_instance_of Module, MUES::Metaclass

		assert_nothing_raised { require 'mues/metaclass/attribute' }
		assert_instance_of Class, MUES::Metaclass::Attribute

		assert_nothing_raised { require 'mues/metaclass/association' }
		assert_instance_of Class, MUES::Metaclass::Association

		assert_nothing_raised { require 'mues/metaclass/operation' }
		assert_instance_of Class, MUES::Metaclass::Operation

		assert_nothing_raised { require 'mues/metaclass/mutatoroperation' }
		assert_instance_of Class, MUES::Metaclass::MutatorOperation

		assert_nothing_raised { require 'mues/metaclass/accessoroperation' }
		assert_instance_of Class, MUES::Metaclass::AccessorOperation

		assert_nothing_raised { require 'mues/metaclass/interface' }
		assert_instance_of Class, MUES::Metaclass::Interface

		assert_nothing_raised { require 'mues/metaclass/namespace' }
		assert_instance_of Class, MUES::Metaclass::Namespace

		assert_nothing_raised { require 'mues/metaclass/parameter' }
		assert_instance_of Class, MUES::Metaclass::Parameter

		assert_nothing_raised { require 'mues/metaclass/class' }
		assert_instance_of Class, MUES::Metaclass::Class
	end

end # class RequireTestCase




