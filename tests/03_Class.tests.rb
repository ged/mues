#!/usr/bin/ruby -w

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
end

require 'mues/Metaclasses'

class ClassTestCase < MUES::TestCase

	include MUES

	### Test instantiation with various arguments
	def test_00Instantiate
		parentClass = nil
		obj = nil

		# 0-arg -- should raise an exception
		assert_raises( ArgumentError ) { Metaclass::Class::new }
		
		# 1-arg
		assert_nothing_raised { obj = Metaclass::Class::new("Tester") }
		assert_instance_of Metaclass::Class, obj

		# 2-arg, illegal second arg
		assert_raises( TypeError ) { Metaclass::Class::new("Tester", "notAClass") }

		# 2-arg, legal second arg
		parentClass = Metaclass::Class::new( "Super" )
		assert_nothing_raised { obj = Metaclass::Class::new("Sub", parentClass) }
	end


	### Test simple accessor methods
	def test_01Accessors
		parentClass = Metaclass::Class::new("Parent")
		testClass = Metaclass::Class::new("Tester", parentClass)

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

		assert_raises( TypeError ) { testClass << "test string" }
	end


	### Test 'add' methods
	def test_03AddMethods
		parentClass = Metaclass::Class::new("Parent")
		testClass = Metaclass::Class::new("Tester", parentClass)

		assert_raises( TypeError ) { testClass.addAttribute "test string" }
		assert_raises( TypeError ) { testClass.addOperation 2 }
		assert_raises( TypeError ) { testClass.addInterface $stderr }

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
		assert_raises( TypeError ) { testClass.removeAttribute 1 }
		assert_raises( ArgumentError ) { testClass.removeOperation }
		assert_raises( TypeError ) { testClass.removeInterface %w{test array} }

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
		testOp = Metaclass::Operation::new 'testOp', '#no-op'
		testClass.addOperation( testOp )
		testIface = Metaclass::Interface::new 'TestIface'
		testClass.addInterface( testIface )

		# Instantiate the anonclass half of the metaclass so we can test the
		# remove methods against it, too.
		instance = testClass::new
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
		assert_raises( ArgumentError ) { instance = myClass::new }

		# Okay, now we call it again with a 'name' parameter, which should succeed.
		assert_nothing_raised { instance = myClass::new("someName") }

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

	def test_16AbstractClass
		parentClass = intermediateClass = myClass = nil
		instance = rval = nil

		assert_nothing_raised {

			# Define the parent class, and add an initializer and a virtual
			# operation to it
			parentClass = Metaclass::Class::new( "Parent" )
			parentClass << Metaclass::Attribute::new( "parentInit" )
			parentClass << Metaclass::Operation::new( "initialize", "@parentInit = true" )
			parentClass << Metaclass::Operation::new( "foo" )

			# Define an intermediate class, don't add any operations. This one
			# should still be abstract
			intermediateClass = Metaclass::Class::new( "Intermediate", parentClass )

			# Now create the child, override the virtual method and the
			# initializer
			myClass = Metaclass::Class::new( "Tester", intermediateClass )
			myClass << Metaclass::Attribute::new( "childInit" )
			myClass << Metaclass::Operation::new( "initialize", "super ; @childInit = true" )
			myClass << Metaclass::Operation::new( "foo", "#no-op" )
		}

		# Make sure instantiating a class with a virtual operation fails.
		assert parentClass.abstract?
		assert_raises( NoMethodError ) { parentClass::new }
		
		# Make sure instantiating the intermediate class fails, too.
		assert intermediateClass.abstract?
		assert_raises( NoMethodError ) { intermediateClass::new }
		
		# Now make sure we can instantiate the class with an overridden version
		# of the virtual operation
		assert_nothing_raised { instance = myClass::new }

		# Call the overridden method
		assert_nothing_raised { instance.foo }

		# Check both ivars
		assert_nothing_raised { rval = instance.parentInit }
		assert rval
		assert_nothing_raised { rval = instance.childInit }
		assert rval
	end

end # class ClassTestCase

