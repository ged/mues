#!/usr/bin/ruby -w
# :nodoc: all
#
# This is a Test::Unit test suite for the PolymorphicObject class.
#

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
end

require "mues"
require 'mues/storableobject'


### Test classes

### Predeclare token class
class PolymorphTestToken < MUES::PolymorphicObject ; end

### Test tokenizable object class for testing
class PolymorphTestObject < MUES::PolymorphicObject
	attr_accessor :value

	def initialize( val )
		@value = val
	end

	def tokenize
		puts "Swizzling object #{self.inspect}" if $DEBUG

		token = PolymorphTestToken.new( @value )
		self.polymorph token
	end
end

### Token object class for testing
class PolymorphTestToken < MUES::PolymorphicObject

	def initialize( val )
		@value = val
	end

	def tokenId
		"token:#{@value}"
	end

	def method_missing( symbol, *args )
		puts "Unswizzling for method #{symbol.id2name}" if $DEBUG
		
		realObj = PolymorphTestObject.new( @value )
		self.polymorph realObj
		self.send( symbol, *args )
	end
	
end

### Container class for testing (un)tokenize across object instances.
class PolymorphTestContainer
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
		self.polymorph other
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
		def test_05_nonpolymorphic_polymorph
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

			assert_nothing_raised { obj = PolymorphTestObject.new("Corbin Dallas") }
			assert_nothing_raised { obj.tokenize }
			assert_instance_of PolymorphTestToken, obj
			assert_nothing_raised { rv = obj.tokenId }
			assert_equal "token:Corbin Dallas", rv
		end

		# Test un-tokenizing
		def test_20_untokenize
			obj = nil
			rv = nil

			assert_nothing_raised { obj = PolymorphTestToken.new("Multipass!") }
			assert_nothing_raised { rv = obj.value }
			assert_instance_of PolymorphTestObject, obj
			assert_equal "Multipass!", rv
		end

		# Test tokenizing across multiple references in instance vars of multiple
		# objects
		def test_30_tokenize_multiref
			obj = PolymorphTestObject.new( "Big badda boom." )
			container1 = PolymorphTestContainer.new( obj )
			container2 = PolymorphTestContainer.new( obj )
			container3 = PolymorphTestContainer.new( container1, container2 )

			assert_nothing_raised { obj.tokenize }

			assert_equal PolymorphTestToken, container1.contents[0].class
			assert_equal PolymorphTestToken, container2.contents[0].class
			assert_equal PolymorphTestToken, container3.contents[0].contents[0].class
		end

		# Test tokenizing across multiple references in instance vars of multiple
		# objects
		def test_40_untokenize_multiref
			obj = PolymorphTestToken.new( "Mmmmm chicken... more chicken." )
			container1 = PolymorphTestContainer.new( obj )
			container2 = PolymorphTestContainer.new( obj )
			container3 = PolymorphTestContainer.new( container1, container2 )

			assert_nothing_raised { obj.value }

			assert_equal PolymorphTestObject, container1.contents[0].class
			assert_equal PolymorphTestObject, container2.contents[0].class
			assert_equal PolymorphTestObject, container3.contents[0].contents[0].class
		end

	end # class PolymorphicObjectPolymorphTestCase
end # module MUES



