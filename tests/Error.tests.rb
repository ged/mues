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

### Test class
class TestObject < PolymorphicObject
	attr_reader :thing

	def initialize
		@thing = 1
	end

	def mutate( other )
		self.become other
	end
end

### Test case class
class PolymorphicObjectErrorTests < RUNIT::TestCase

	def setup
		@testObj = TestObject.new
	end

	def teardown
		@testObj = nil
	end

	# Make sure loading works
	def test_00_nonpolymorphic_become
		other = "a string"
		assert_exception( TypeError ) { @testObj.mutate other }

		yetAnother = 1
		assert_exception( TypeError ) { @testObj.mutate yetAnother }
	end

end

if $0 == __FILE__
    RUNIT::CUI::TestRunner.run(PolymorphicObjectErrorTests.suite)
end


