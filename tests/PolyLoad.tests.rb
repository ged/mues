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

module MUES
	class PolymorphicObjectLoadTests < MUES::TestCase

		# Make sure loading works
		def test_00_require
			assert_not_nil $".detect {|lib| lib =~ /mues\.so/ }
			assert_instance_of( Class, MUES::PolymorphicObject )
		end

	end
end


