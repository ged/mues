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

### Test class
class TestObject < MUES::PolymorphicObject
	attr_reader :thing

	def initialize
		@thing = 1
	end

	def mutate( other )
		self.become other
	end
end


module MUES

	### Test case class
	class PolymorphicObjectErrorTests < MUES::TestCase

		def set_up
			@testObj = TestObject.new
		end

		def tear_down
			@testObj = nil
		end

		# Make sure loading works
		def test_00_nonpolymorphic_become
			other = "a string"
			assert_raises( TypeError ) { @testObj.mutate other }

			yetAnother = 1
			assert_raises( TypeError ) { @testObj.mutate yetAnother }
		end

	end
end


