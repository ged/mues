#!/usr/bin/ruby -w

require 'test/unit'

class RequireTestCase < Test::Unit::TestCase

	def test_requires
		assert_nothing_raised { require 'metaclass/Constants' }
		assert_instance_of Module, Metaclass

		assert_nothing_raised { require 'metaclass/Attribute' }
		assert_instance_of Class, Metaclass::Attribute

		assert_nothing_raised { require 'metaclass/Association' }
		assert_instance_of Class, Metaclass::Association

		assert_nothing_raised { require 'metaclass/Operation' }
		assert_instance_of Class, Metaclass::Operation

		assert_nothing_raised { require 'metaclass/MutatorOperation' }
		assert_instance_of Class, Metaclass::MutatorOperation

		assert_nothing_raised { require 'metaclass/AccessorOperation' }
		assert_instance_of Class, Metaclass::AccessorOperation

		assert_nothing_raised { require 'metaclass/Interface' }
		assert_instance_of Class, Metaclass::Interface

		assert_nothing_raised { require 'metaclass/Namespace' }
		assert_instance_of Class, Metaclass::Namespace

		assert_nothing_raised { require 'metaclass/Parameter' }
		assert_instance_of Class, Metaclass::Parameter

		assert_nothing_raised { require 'metaclass/Class' }
		assert_instance_of Class, Metaclass::Class
	end

end # class RequireTestCase




