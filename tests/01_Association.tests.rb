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

# Mock object
class MockAssnSubclass < MUES::Metaclass::Association
	public_class_method :new
end

class AssociationTestCase < MUES::TestCase

	### Test instantiation with various arguments
	def test_00Instantiate
		assert_raises( NoMethodError ) { MUES::Metaclass::Association::new }
	end

	### Test subclass instantiation
	def test_01SubclassInstantiation
		obj = nil

		# No-arg (should raise an ArgumentError)
		assert_raises( ArgumentError ) { MockAssnSubclass::new }

		# One-arg. Test inherited initializer and accessor
		assert_nothing_raised { obj = MockAssnSubclass::new("thename") }
		assert_equal "thename", obj.name
	end

end # class AssociationTestCase

