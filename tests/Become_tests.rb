#!/usr/bin/ruby -w
#
# This is a rubyunit test suite for the MonadicObject class.
#

# Add the parent directory if we're running inside t/
if $0 == __FILE__
	$LOAD_PATH.unshift( ".." ) if File.directory?( "../extconf.rb" )
end

require "runit/cui/testrunner"
require "runit/testcase"
require "MonadicObject"

### Test class
class BecomeTestToken < MonadicObject ; end

class BecomeTestObject < MonadicObject
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

class BecomeTestToken < MonadicObject

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

### Test case class
class MonadicObjectBecomeTests < RUNIT::TestCase

	# Test tokenizing the test object
	def test_00_tokenize
		obj = nil
		rv = nil

		assert_no_exception { obj = BecomeTestObject.new("tokenize") }
		assert_no_exception { obj.tokenize }
		assert_instance_of BecomeTestToken, obj
		assert_no_exception { rv = obj.tokenId }
		assert_equal "token:tokenize", rv
	end

	# Test un-tokenizing
	def test_01_untokenize
		obj = nil
		rv = nil

		assert_no_exception { obj = BecomeTestToken.new("untokenize") }
		assert_no_exception { rv = obj.value }
		assert_instance_of BecomeTestObject, obj
		assert_equal "untokenize", rv
	end

end

if $0 == __FILE__
    RUNIT::CUI::TestRunner.run(MonadicObjectBecomeTests.suite)
end


