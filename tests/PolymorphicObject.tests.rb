#!/usr/bin/ruby -w
# :nodoc: all
#
# This is a Test::Unit test suite for the PolymorphicObject class.
#

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require "mues"
require "mues/StorableObject"


### Test classes

### Predeclare token class
class BecomeTestToken < MUES::PolymorphicObject ; end

### Test tokenizable object class for testing
class BecomeTestObject < MUES::PolymorphicObject
	attr_accessor :value

	def initialize( val )
		@value = val
	end

	def tokenize
		puts "Swizzling object #{self.inspect}" if $DEBUG

		token = BecomeTestToken.new( @value )
		self.become token
	end
end

### Token object class for testing
class BecomeTestToken < MUES::PolymorphicObject

	def initialize( val )
		@value = val
	end

	def tokenId
		"token:#{@value}"
	end

	def method_missing( symbol, *args )
		puts "Unswizzling for method #{symbol.id2name}" if $DEBUG
		
		realObj = BecomeTestObject.new( @value )
		self.become realObj
		self.send( symbol, *args )
	end
	
end

### Container class for testing (un)tokenize across object instances.
class BecomeTestContainer
	attr_reader :contents
	def initialize( *contents )
		@contents = contents
	end
end


### Test class
class PolyTestObject < MUES::PolymorphicObject
	attr_reader :thing

	def initialize
		@thing = 1
	end

	def mutate( other )
		self.become other
	end
end


module MUES

	# Test case class
	class PolymorphicObjectTestCase < MUES::TestCase

		# Make sure loading works
		def test_00_require
			assert_not_nil $".detect {|lib| lib =~ /mues\.so/ }
			assert_instance_of( Class, MUES::PolymorphicObject )
		end

		# Test to be sure 
		def test_05_nonpolymorphic_become
			testObj = PolyTestObject::new

			other = "a string"
			assert_raises( TypeError ) { testObj.mutate other }

			yetAnother = 1
			assert_raises( TypeError ) { testObj.mutate yetAnother }
		end

		# Test tokenizing the test object
		def test_10_tokenize
			obj = nil
			rv = nil

			assert_nothing_raised { obj = BecomeTestObject.new("Corbin Dallas") }
			assert_nothing_raised { obj.tokenize }
			assert_instance_of BecomeTestToken, obj
			assert_nothing_raised { rv = obj.tokenId }
			assert_equal "token:Corbin Dallas", rv
		end

		# Test un-tokenizing
		def test_20_untokenize
			obj = nil
			rv = nil

			assert_nothing_raised { obj = BecomeTestToken.new("Multipass!") }
			assert_nothing_raised { rv = obj.value }
			assert_instance_of BecomeTestObject, obj
			assert_equal "Multipass!", rv
		end

		# Test tokenizing across multiple references in instance vars of multiple
		# objects
		def test_30_tokenize_multiref
			obj = BecomeTestObject.new( "Big badda boom." )
			container1 = BecomeTestContainer.new( obj )
			container2 = BecomeTestContainer.new( obj )
			container3 = BecomeTestContainer.new( container1, container2 )

			assert_nothing_raised { obj.tokenize }

			assert_equal BecomeTestToken, container1.contents[0].class
			assert_equal BecomeTestToken, container2.contents[0].class
			assert_equal BecomeTestToken, container3.contents[0].contents[0].class
		end

		# Test tokenizing across multiple references in instance vars of multiple
		# objects
		def test_40_untokenize_multiref
			obj = BecomeTestToken.new( "Mmmmm chicken... more chicken." )
			container1 = BecomeTestContainer.new( obj )
			container2 = BecomeTestContainer.new( obj )
			container3 = BecomeTestContainer.new( container1, container2 )

			assert_nothing_raised { obj.value }

			assert_equal BecomeTestObject, container1.contents[0].class
			assert_equal BecomeTestObject, container2.contents[0].class
			assert_equal BecomeTestObject, container3.contents[0].contents[0].class
		end

	end # class PolymorphicObjectBecomeTestCase
end # module MUES



