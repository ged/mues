#!/usr/bin/ruby -w
# :nodoc: all
#
# This is a rubyunit test suite for the PolymorphicObject class.
#

# Add the parent directory if we're running inside t/
if $0 == __FILE__
	$LOAD_PATH.unshift( ".." ) if File.directory?( "../extconf.rb" )
end

require "runit/cui/testrunner"
require "runit/testcase"
require "PolymorphicObject"

### Test classes

# Predeclare token class
class BecomeTestToken < PolymorphicObject ; end

##
# Test tokenizable object class for testing
class BecomeTestObject < PolymorphicObject
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

##
# Token object class for testing
class BecomeTestToken < PolymorphicObject

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

##
# Container class for testing (un)tokenize across object instances.
class BecomeTestContainer
	attr_reader :contents
	def initialize( *contents )
		@contents = contents
	end
end


##
# Test case class
class PolymorphicObjectBecomeTests < RUNIT::TestCase

	# Test tokenizing the test object
	def test_00_tokenize
		obj = nil
		rv = nil

		assert_no_exception { obj = BecomeTestObject.new("Corbin Dallas") }
		assert_no_exception { obj.tokenize }
		assert_instance_of BecomeTestToken, obj
		assert_no_exception { rv = obj.tokenId }
		assert_equal "token:Corbin Dallas", rv
	end

	# Test un-tokenizing
	def test_01_untokenize
		obj = nil
		rv = nil

		assert_no_exception { obj = BecomeTestToken.new("Multipass!") }
		assert_no_exception { rv = obj.value }
		assert_instance_of BecomeTestObject, obj
		assert_equal "Multipass!", rv
	end

	# Test tokenizing across multiple references in instance vars of multiple
	# objects
	def test_02_tokenize_multiref
		obj = BecomeTestObject.new( "Big badda boom." )
		container1 = BecomeTestContainer.new( obj )
		container2 = BecomeTestContainer.new( obj )
		container3 = BecomeTestContainer.new( container1, container2 )

		assert_no_exception { obj.tokenize }

		assert_equals BecomeTestToken, container1.contents[0].class
		assert_equals BecomeTestToken, container2.contents[0].class
		assert_equals BecomeTestToken, container3.contents[0].contents[0].class
	end

	# Test tokenizing across multiple references in instance vars of multiple
	# objects
	def test_03_untokenize_multiref
		obj = BecomeTestToken.new( "Mmmmm chicken... more chicken." )
		container1 = BecomeTestContainer.new( obj )
		container2 = BecomeTestContainer.new( obj )
		container3 = BecomeTestContainer.new( container1, container2 )

		assert_no_exception { obj.value }

		assert_equals BecomeTestObject, container1.contents[0].class
		assert_equals BecomeTestObject, container2.contents[0].class
		assert_equals BecomeTestObject, container3.contents[0].contents[0].class
	end

end

if $0 == __FILE__
    RUNIT::CUI::TestRunner.run(PolymorphicObjectBecomeTests.suite)
end


