#!/usr/bin/ruby -w

unless defined? MUES && defined? MUES::TestCase
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )

	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/ext" unless
		$LOAD_PATH.include?( "#{basedir}/ext" )
	$LOAD_PATH.unshift "#{basedir}/tests" unless
		$LOAD_PATH.include?( "#{basedir}/tests" )

	require 'muestestcase'
end

require 'mues/metaclasses'


class AttributeTestCase < MUES::TestCase

	include MUES
	include MUES::Metaclass::Scope
	include MUES::Metaclass::Visibility

	### Test no-arg instantiation
	def test_00NoArg_Instantiate
		attrObj = nil

		# No-args, should raise an ArgumentError
		assert_raises( ArgumentError ) { Metaclass::Attribute::new }
		assert_raises( TypeError ) { Metaclass::Attribute::new(14) }
	end

	# One-arg
	def test_01OneArg_Instantiate
		attrObj = nil

		assert_nothing_raised { attrObj = Metaclass::Attribute::new("name") }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_nothing_raised { attrObj = Metaclass::Attribute::new(:name) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_equal INSTANCE, attrObj.scope
		assert_equal PUBLIC, attrObj.visibility
		assert_equal [], attrObj.validTypes
	end

	# Two-arg, single validType
	def test_02TwoArgValidType_Instantiate
		attrObj = nil

		assert_nothing_raised { attrObj = Metaclass::Attribute::new("name",String) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_nothing_raised { attrObj = Metaclass::Attribute::new(:name,String) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_equal INSTANCE, attrObj.scope
		assert_equal PUBLIC, attrObj.visibility
		assert_equal [String], attrObj.validTypes
	end

	# Two-arg, multiple class validTypes
	def test_03TwoArgMultipleValidType_Instantiate
		attrObj = nil

		assert_nothing_raised { attrObj = Metaclass::Attribute::new("gameid",[String,"Numeric",Array,"IO"]) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "gameid", attrObj.name
		assert_nothing_raised { attrObj = Metaclass::Attribute::new(:gameid,[String,"Numeric",Array,"IO"]) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "gameid", attrObj.name
		assert_equal INSTANCE, attrObj.scope
		assert_equal PUBLIC, attrObj.visibility
		assert_instance_of Array, attrObj.validTypes
		assert_not_nil attrObj.validTypes.detect {|obj| obj == String}
		assert_not_nil attrObj.validTypes.detect {|obj| obj == "Numeric"}
		assert_not_nil attrObj.validTypes.detect {|obj| obj == Array}
		assert_not_nil attrObj.validTypes.detect {|obj| obj == "IO"}
	end

	# Three-arg, instance scope
	def test_04ThreeArgInstance_Instantiate
		attrObj = nil

		assert_nothing_raised { attrObj = Metaclass::Attribute::new("name",String,INSTANCE) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_nothing_raised { attrObj = Metaclass::Attribute::new(:name,String,INSTANCE) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_equal INSTANCE, attrObj.scope
		assert_equal PUBLIC, attrObj.visibility
	end

	# Three-arg, class scope
	def test_05ThreeArgClass_Instantiate
		attrObj = nil

		assert_nothing_raised { attrObj = Metaclass::Attribute::new("name",String,CLASS) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_nothing_raised { attrObj = Metaclass::Attribute::new(:name,String,CLASS) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_equal CLASS, attrObj.scope
		assert_equal PUBLIC, attrObj.visibility
	end

	# Four-arg, public
	def test_06FourArgPublic_Instantiate
		attrObj = nil

		assert_nothing_raised { attrObj = Metaclass::Attribute::new("name",String,INSTANCE,PUBLIC) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_nothing_raised { attrObj = Metaclass::Attribute::new(:name,String,INSTANCE,PUBLIC) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_equal INSTANCE, attrObj.scope
		assert_equal PUBLIC, attrObj.visibility
	end

	# Four-arg, protected
	def test_07FourArgProtected_Instantiate
		attrObj = nil

		assert_nothing_raised { attrObj = Metaclass::Attribute::new("name",String,INSTANCE,PROTECTED) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_nothing_raised { attrObj = Metaclass::Attribute::new(:name,String,INSTANCE,PROTECTED) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_equal INSTANCE, attrObj.scope
		assert_equal PROTECTED, attrObj.visibility
	end

	# Four-arg, private
	def test_08FourArgPrivate_Instantiate
		attrObj = nil

		assert_nothing_raised { attrObj = Metaclass::Attribute::new("name",String,INSTANCE,PRIVATE) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_nothing_raised { attrObj = Metaclass::Attribute::new(:name,String,INSTANCE,PRIVATE) }
		assert_instance_of Metaclass::Attribute, attrObj
		assert_equal "name", attrObj.name
		assert_equal INSTANCE, attrObj.scope
		assert_equal PRIVATE, attrObj.visibility
	end

	### Test the Comparable interface operators/methods
	def test_09Comparable
		aInstance	= Metaclass::Attribute::new( "a", nil, INSTANCE )
		bInstance	= Metaclass::Attribute::new( "b", nil, INSTANCE )
		cInstance	= Metaclass::Attribute::new( "c", nil, INSTANCE )
		aClass		= Metaclass::Attribute::new( "a", nil, CLASS )
		cClass		= Metaclass::Attribute::new( "c", nil, CLASS )

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

	### Test the addition of accessors when adding an attribute to a class
	def test_10AccessorOp
		attrObj = Metaclass::Attribute::new( "key", [String,Numeric] )
		op = nil

		assert_nothing_raised { op = attrObj.makeAccessorOp }
		assert_kind_of Metaclass::Operation, op
		assert_equal "key", op.name
		assert_equal INSTANCE, op.scope
		assert_equal PUBLIC, op.visibility

	end

	### Test the addition of mutators when adding an attribute to a class
	def test_11MutatorOp
		attrObj = Metaclass::Attribute::new( "key", [String,Numeric] )
		op = nil

		assert_nothing_raised { op = attrObj.makeMutatorOp }
		assert_kind_of Metaclass::Operation, op
		assert_equal "key=", op.name
		assert_equal INSTANCE, op.scope
		assert_equal PUBLIC, op.visibility

	end

end # class AttributeTestCase

