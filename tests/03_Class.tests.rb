#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'metaclasses'

class ClassTestCase < MUES::TestCase

	### Test instantiation with various arguments
	def test_00Instantiate
		parentClass = nil
		obj = nil

		# 0-arg -- should raise an exception
		assert_raises( ArgumentError ) { Metaclass::Class.new }
		
		# 1-arg
		assert_nothing_raised { obj = Metaclass::Class.new("Tester") }
		assert_instance_of Metaclass::Class, obj

		# 2-arg, illegal second arg
		assert_raises( ArgumentError ) { Metaclass::Class.new("Tester", "notAClass") }

		# 2-arg, legal second arg
		parentClass = Metaclass::Class.new( "Super" )
		assert_nothing_raised { obj = Metaclass::Class.new("Sub", parentClass) }
	end


	### Test simple accessor methods
	def test_01Accessors
		parentClass = Metaclass::Class.new("Parent")
		testClass = Metaclass::Class.new("Tester", parentClass)

		assert_equal "Tester", testClass.name
		assert_instance_of Hash, testClass.operations
		assert_instance_of Hash, testClass.classOperations
		assert_instance_of Hash, testClass.attributes
		assert_instance_of Hash, testClass.classAttributes
		assert_instance_of Array, testClass.interfaces
		assert_same parentClass, testClass.superclass
	end


	### Test append operator
	def test_02AppendOpMethod
		parentClass = Metaclass::Class::new("Parent")
		testClass = Metaclass::Class::new("Tester", parentClass)

		assert_nothing_raised { testClass << Metaclass::Attribute::new('testAttr') }
		assert_nothing_raised { testClass << Metaclass::Operation::new('testOp') }
		assert_nothing_raised { testClass << Metaclass::Interface::new('TestIface') }

		assert_raises( ArgumentError ) { testClass << "test string" }
	end


	### Test 'add' methods
	def test_03AddMethods
		parentClass = Metaclass::Class::new("Parent")
		testClass = Metaclass::Class::new("Tester", parentClass)

		assert_raises( ArgumentError ) { testClass.addAttribute "test string" }
		assert_raises( ArgumentError ) { testClass.addOperation 2 }
		assert_raises( ArgumentError ) { testClass.addInterface $stderr }

		assert_nothing_raised { testClass.addAttribute Metaclass::Attribute::new('testAttr') }
		assert_nothing_raised { testClass.addOperation Metaclass::Operation::new('testOp') }
		assert_nothing_raised { testClass.addInterface Metaclass::Interface::new('TestIface') }
	end


	### Test 'remove' methods
	def test_04RemoveMethods
		parentClass = Metaclass::Class::new("Parent")
		testClass = Metaclass::Class::new("Tester", parentClass)
		rval = nil
		testAttr, testOp, testIface = nil, nil, nil

		# Test illegal arguments, no arguments
		assert_raises( ArgumentError ) { testClass.removeAttribute 1 }
		assert_raises( ArgumentError ) { testClass.removeOperation }
		assert_raises( ArgumentError ) { testClass.removeInterface %w{test array} }

		# Test removing ones that don't exist yet
		assert_nothing_raised { rval = testClass.removeAttribute 'testAttr' }
		assert_equal nil, rval
		assert_nothing_raised { rval = testClass.removeOperation 'testOp' }
		assert_equal nil, rval
		assert_nothing_raised { rval = testClass.removeInterface 'TestIface' }
		assert_equal nil, rval

		# Add items so we can remove 'em
		testAttr = Metaclass::Attribute::new 'testAttr'
		testClass.addAttribute( testAttr )
		testOp = Metaclass::Operation::new 'testOp'
		testClass.addOperation( testOp )
		testIface = Metaclass::Interface::new 'TestIface'
		testClass.addInterface( testIface )

		# Instantiate the anonclass half of the metaclass so we can test the
		# remove methods against it, too.
		instance = testClass.new
		assert_respond_to( instance, :testOp )
		assert_respond_to( instance, :testAttr )
		assert_respond_to( instance, :testAttr= )
		
		# Remove the items
		assert_nothing_raised { rval = testClass.removeAttribute 'testAttr' }
		assert_equal testAttr, rval
		assert_nothing_raised { rval = testClass.removeOperation 'testOp' }
		assert_equal testOp, rval
		assert_nothing_raised { rval = testClass.removeInterface 'TestIface' }
		assert_equal testIface, rval

		# Test the instance to see if the methods have been removed, too
		assert !instance.respond_to?( :testOp )
		assert !instance.respond_to?( :testAttr )
		assert !instance.respond_to?( :testAttr= )

	end


	### Test 'has?' methods
	def test_05HasMethods
		parentClass = Metaclass::Class::new("Parent")
		testClass = Metaclass::Class::new("Tester", parentClass)
		rval = nil
		testAttr, testOp, testIface = nil, nil, nil

		# Add items so we can test for 'em
		testAttr = Metaclass::Attribute::new 'testAttr'
		testClass.addAttribute( testAttr )
		testOp = Metaclass::Operation::new 'testOp'
		testClass.addOperation( testOp )
		testIface = Metaclass::Interface::new 'TestIface'
		testClass.addInterface( testIface )

		# Now test the has? methods
		assert testClass.hasAttribute?( testAttr )
		assert testClass.hasOperation?( testOp )
		assert testClass.includesInterface?( testIface )
	end

	
	### Test comparison operator
	def test_06Comparable
		aClass = Metaclass::Class::new( "a" )
		bClass = Metaclass::Class::new( "b", aClass )
		cClass = Metaclass::Class::new( "c", bClass )
		dClass = Metaclass::Class::new( "d", aClass )
		rval = nil

		assert bClass < aClass
		assert cClass < bClass
		assert dClass < aClass

		assert !(dClass < cClass)

		# Between method
		assert bClass.between?( aClass, cClass ), "B wasn't between A and C"
		assert !( bClass.between?( cClass, dClass ) ), "B *was* between C and D"
		
	end


	### Test a complete little class definition
	def test_15Definition
		instance = nil
		rval = nil
		parentClass = nil
		myClass = nil

		# None of this should raise an exception
		assert_nothing_raised {

			# Define its parent class
			parentClass = Metaclass::Class::new( "Parent" )

			# Define the class object itself
			myClass = Metaclass::Class::new( "Tester", parentClass )

			# Add an initializer method...
			initializer = Metaclass::Operation::new( "initialize", <<-"EOF" )
				@name = name
			EOF
			initializer << Metaclass::Parameter::new( "name", String )
			myClass.addOperation( initializer )

			# Add a 'name' attribute
			myClass << Metaclass::Attribute::new( "name" )
			myClass << Metaclass::Attribute::new( "count", Integer, Metaclass::Scope::CLASS )

			# Add an 'inspect' method
			myClass << Metaclass::Operation::new( "inspect", <<-"EOF" )
				return "[test object %s %d]" % [ self.name, self.id ]
			EOF
		}

		### Now test out the class

		# Since the initializer has a parameter with no default, this should raise an error.
		assert_raises( ArgumentError ) { instance = myClass.new }

		# Okay, now we call it again with a 'name' parameter, which should succeed.
		assert_nothing_raised { instance = myClass.new("someName") }

		# It should result in an anonymous class object...
		assert_instance_of myClass.classObj, instance

		# and inherit from the anonclass parent...
		assert_kind_of parentClass.classObj, instance

		# and support the inspect method...
		assert_nothing_raised { rval = instance.inspect }
		assert_equal "[test object someName #{instance.id}]", rval

		# And the class object should support the 'count' method
		assert_respond_to myClass.classObj, :count
	end

end # class ClassTestCase

