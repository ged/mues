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

class InterfaceTestCase < MUES::TestCase

	include MUES

	### Test instantiation with various arguments
	def test_00Instantiate
		iface = nil
		superIface = nil

		# 0-arg -- should raise an exception
		assert_raises( ArgumentError ) { Metaclass::Interface::new }
		
		# 1-arg
		assert_nothing_raised { iface = Metaclass::Interface::new("Testable") }
		assert_instance_of Metaclass::Interface, iface

		# 2-arg, superclass = non-interface -- should raise
		assert_raises( TypeError ) { Metaclass::Interface::new("Testable", "foo") }

		# 2-arg, superclass = interface
		superIface = Metaclass::Interface::new( "Proddable" )
		assert_nothing_raised { iface = Metaclass::Interface::new("Testable", superIface) }
		assert_instance_of Metaclass::Interface, iface
	end

	### Test simple accessor methods
	def test_01Accessors
		iface = Metaclass::Interface.new("Testable")

		assert_equal "Testable", iface.name
		assert_instance_of Hash, iface.operations
		assert_instance_of Hash, iface.classOperations
		assert_instance_of Hash, iface.attributes
		assert_instance_of Hash, iface.classAttributes
		# assert_same parentIface, iface.superclass
	end


	### Test append operator
	def test_02AppendOpMethod
		iface = Metaclass::Interface::new("Testable")

		assert_nothing_raised { iface << Metaclass::Attribute::new('testAttr') }
		assert_nothing_raised { iface << Metaclass::Operation::new('testOp') }
		# assert_nothing_raised { iface << Metaclass::Interface::new('TestIface') }

		assert_raises( ArgumentError ) { iface << "test string" }
	end


	### Test 'add' methods
	def test_03AddMethods
		iface = Metaclass::Interface::new("Testable")

		assert_raises( TypeError ) { iface.addAttribute "test string" }
		assert_raises( TypeError ) { iface.addOperation 2 }
		#assert_raises( TypeError ) { iface.addInterface $stderr }

		assert_nothing_raised { iface.addAttribute Metaclass::Attribute::new('testAttr') }
		assert_nothing_raised { iface.addOperation Metaclass::Operation::new('testOp') }
		#assert_nothing_raised { iface.addInterface Metaclass::Interface::new('TestIface') }
	end


	### Test 'remove' methods
	def test_04RemoveMethods
		iface = Metaclass::Interface::new("Testable")
		rval = nil
		testAttr, testOp = nil, nil

		# Test illegal arguments, no arguments
		assert_raises( TypeError ) { iface.removeAttribute 1 }
		assert_raises( ArgumentError ) { iface.removeOperation }

		# Test removing ones that don't exist yet
		assert_nothing_raised { rval = iface.removeAttribute 'testAttr' }
		assert_equal nil, rval
		assert_nothing_raised { rval = iface.removeOperation 'testOp' }
		assert_equal nil, rval

		# Add items so we can remove 'em
		testAttr = Metaclass::Attribute::new 'testAttr'
		iface.addAttribute( testAttr )
		testOp = Metaclass::Operation::new 'testOp'
		iface.addOperation( testOp )

		# Remove the items
		assert_nothing_raised { rval = iface.removeAttribute 'testAttr' }
		assert_equal testAttr, rval
		assert_nothing_raised { rval = iface.removeOperation 'testOp' }
		assert_equal testOp, rval
	end


	### Test 'has?' methods
	def test_05HasMethods
		iface = Metaclass::Interface::new("Testable")
		rval = nil
		testAttr, testOp, testIface = nil, nil, nil

		# Add items so we can test for 'em
		testAttr = Metaclass::Attribute::new 'testAttr'
		iface.addAttribute( testAttr )
		testOp = Metaclass::Operation::new 'testOp'
		iface.addOperation( testOp )

		# Now test the has? methods
		assert iface.hasAttribute?( testAttr )
		assert iface.hasOperation?( testOp )
	end

	
	### Test a complete little class definition + interface
	def test_15Definition
		iface		= nil
		testClass	= nil
		instance	= nil
		rval		= nil

		# None of this should raise an exception
		assert_nothing_raised {

			# Define a class to apply the interface to
			testClass = Metaclass::Class::new( "Victim" )

			# Define the class object itself
			iface = Metaclass::Interface::new( "Testable" )

			# Add an initializer method...
			initializer = Metaclass::Operation::new( "initialize", <<-"EOF" )
				@name = name
			EOF
			initializer << Metaclass::Parameter::new( "name", String )
			iface.addOperation( initializer )

			# Add a 'name' attribute
			iface << Metaclass::Attribute::new( "name" )
			iface << Metaclass::Attribute::new( "count", Integer, Metaclass::Scope::CLASS )

			# Add an 'inspect' method
			iface << Metaclass::Operation::new( "inspect", <<-"EOF" )
				return "[test object %s %d]" % [ self.name, self.id ]
			EOF

			# Now add the interface to the class
			testClass << iface
		}

		### Now test out the interface through the class
		$stderr.puts iface.moduleDefinition if $DEBUG

		# Make sure the object's a Module
		assert_nothing_raised { rval = iface.moduleObj }
		assert_instance_of Module, rval

		# Since the initializer has a parameter with no default, this should raise an error.
		testClass.new("appendtest")
		assert_raises( ArgumentError ) { instance = testClass.new }

		# Okay, now we call it again with a 'name' parameter, which should succeed.
		assert_nothing_raised { instance = testClass.new("someName") }

		# It should result in an anonymous class object...
		assert_instance_of testClass.classObj, instance

		# and support the inspect method...
		assert_nothing_raised { rval = instance.inspect }
		assert_equal "[test object someName #{instance.object_id}]", rval

		# And the class object should support the 'count' method
		assert_respond_to testClass.classObj, :count # <- Doesn't work yet.
	end


end # class InterfaceTestCase

