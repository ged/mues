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

class PolymorphicObjectLoadTests < RUNIT::TestCase

	# Make sure loading works
	def test_00_require
		assert_not_nil $".detect {|lib| lib =~ /PolymorphicObject\.so/ }
		assert_instance_of( Class, PolymorphicObject )
	end

end

if $0 == __FILE__
    RUNIT::CUI::TestRunner.run(PolymorphicObjectLoadTests.suite)
end


