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

class MonadicObjectLoadTests < RUNIT::TestCase

	# Make sure loading works
	def test_00_require
		assert_not_nil $".detect {|lib| lib =~ /MonadicObject\.so/ }
		assert_instance_of( Class, MonadicObject )
	end

end

if $0 == __FILE__
    RUNIT::CUI::TestRunner.run(MonadicObjectLoadTests.suite)
end


