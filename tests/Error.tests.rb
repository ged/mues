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
class TestObject < MonadicObject
	attr_reader :thing

	def initialize
		@thing = 1
	end

	def mutate( other )
		self.become other
	end
end

### Test case class
class MonadicObjectErrorTests < RUNIT::TestCase

	def setup
		@testObj = TestObject.new
	end

	def teardown
		@testObj = nil
	end

	# Make sure loading works
	def test_00_nonmonadic_become
		other = "a string"
		assert_exception( TypeError ) { @testObj.mutate other }

		yetAnother = 1
		assert_exception( TypeError ) { @testObj.mutate yetAnother }
	end

end

if $0 == __FILE__
    RUNIT::CUI::TestRunner.run(MonadicObjectErrorTests.suite)
end


