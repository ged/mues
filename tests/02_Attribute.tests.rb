#!/usr/bin/ruby -w

require 'metaclass/Constants'
require 'metaclass/Attribute'

require 'test/unit'

### Log tests
module Metaclass
	class AttributeTestCase < Test::Unit::TestCase

		include Metaclass::Scope
		include Metaclass::Visibility

		### Test instantiation with various arguments
		def test_Instantiate
			attrObj = nil

			# No-args, should raise an ArgumentError
			assert_raises( ArgumentError ) { Metaclass::Attribute.new }
			assert_raises( TypeError ) { Metaclass::Attribute.new(14) }

			# One-arg
			assert_nothing_raised { attrObj = Metaclass::Attribute.new("name") }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_nothing_raised { attrObj = Metaclass::Attribute.new(:name) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_equal INSTANCE, attrObj.scope
			assert_equal PUBLIC, attrObj.visibility
			assert_equal [], attrObj.validTypes

			# Two-arg, single validType
			assert_nothing_raised { attrObj = Metaclass::Attribute.new("name",String) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_nothing_raised { attrObj = Metaclass::Attribute.new(:name,String) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_equal INSTANCE, attrObj.scope
			assert_equal PUBLIC, attrObj.visibility
			assert_equal [String], attrObj.validTypes

			# Two-arg, multiple class validTypes
			assert_nothing_raised { attrObj = Metaclass::Attribute.new("gameid",[String,"Numeric",Array,"IO"]) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "gameid", attrObj.name
			assert_nothing_raised { attrObj = Metaclass::Attribute.new(:gameid,[String,"Numeric",Array,"IO"]) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "gameid", attrObj.name
			assert_equal INSTANCE, attrObj.scope
			assert_equal PUBLIC, attrObj.visibility
			assert_instance_of Array, attrObj.validTypes
			assert_not_nil attrObj.validTypes.detect {|obj| obj == String}
			assert_not_nil attrObj.validTypes.detect {|obj| obj == "Numeric"}
			assert_not_nil attrObj.validTypes.detect {|obj| obj == Array}
			assert_not_nil attrObj.validTypes.detect {|obj| obj == "IO"}

			# Three-arg, instance scope
			assert_nothing_raised { attrObj = Metaclass::Attribute.new("name",String,INSTANCE) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_nothing_raised { attrObj = Metaclass::Attribute.new(:name,String,INSTANCE) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_equal INSTANCE, attrObj.scope
			assert_equal PUBLIC, attrObj.visibility

			# Three-arg, class scope
			assert_nothing_raised { attrObj = Metaclass::Attribute.new("name",String,CLASS) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_nothing_raised { attrObj = Metaclass::Attribute.new(:name,String,CLASS) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_equal CLASS, attrObj.scope
			assert_equal PUBLIC, attrObj.visibility

			# Four-arg, public
			assert_nothing_raised { attrObj = Metaclass::Attribute.new("name",String,INSTANCE,PUBLIC) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_nothing_raised { attrObj = Metaclass::Attribute.new(:name,String,INSTANCE,PUBLIC) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_equal INSTANCE, attrObj.scope
			assert_equal PUBLIC, attrObj.visibility

			# Three-arg, protected
			assert_nothing_raised { attrObj = Metaclass::Attribute.new("name",String,INSTANCE,PROTECTED) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_nothing_raised { attrObj = Metaclass::Attribute.new(:name,String,INSTANCE,PROTECTED) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_equal INSTANCE, attrObj.scope
			assert_equal PROTECTED, attrObj.visibility

			# Three-arg, private
			assert_nothing_raised { attrObj = Metaclass::Attribute.new("name",String,INSTANCE,PRIVATE) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_nothing_raised { attrObj = Metaclass::Attribute.new(:name,String,INSTANCE,PRIVATE) }
			assert_instance_of Metaclass::Attribute, attrObj
			assert_equal "name", attrObj.name
			assert_equal INSTANCE, attrObj.scope
			assert_equal PRIVATE, attrObj.visibility
		end

		### Test the Comparable interface operators/methods
		def test_Comparable
			aInstance	= Metaclass::Attribute.new( "a", nil, INSTANCE )
			bInstance	= Metaclass::Attribute.new( "b", nil, INSTANCE )
			cInstance	= Metaclass::Attribute.new( "c", nil, INSTANCE )
			aClass		= Metaclass::Attribute.new( "a", nil, CLASS )
			cClass		= Metaclass::Attribute.new( "c", nil, CLASS )

			# Name sort
			assert aInstance < bInstance

			# Scope sort
			assert aInstance < aClass

			# Scope sort
			assert cInstance < aClass

			# Name sort
			assert aClass < cClass

			# Between method
			assert bInstance.between?( aInstance, cInstance )
			assert !bInstance.between?( cInstance, cClass )
			
		end

		def test_AccessorOp
			attrObj = Metaclass::Attribute.new( "key", [String,Numeric] )
			op = nil

			assert_nothing_raised { op = attrObj.makeAccessorOp }
			assert_kind_of Metaclass::Operation, op
			assert_equal "key", op.name
			assert_equal INSTANCE, op.scope
			assert_equal PUBLIC, op.visibility

		end

		def test_MutatorOp
			attrObj = Metaclass::Attribute.new( "key", [String,Numeric] )
			op = nil

			assert_nothing_raised { op = attrObj.makeMutatorOp }
			assert_kind_of Metaclass::Operation, op
			assert_equal "key=", op.name
			assert_equal INSTANCE, op.scope
			assert_equal PUBLIC, op.visibility

		end

	end # class AttributeTestCase
end # module Metaclass

