#!/usr/bin/ruby
# 
# This is an abstract test case class for building Test::Unit unit tests for the
# MUES. It consolidates most of the maintenance work that must be done to build
# a test file by adjusting the $LOAD_PATH to include the lib/ and ext/
# directories, as well as adding some other useful methods that make building
# and maintaining the tests much easier (IMHO). See the docs for Test::Unit for
# more info on the particulars of unit testing.
# 
# == Synopsis
# 
#	# Allow the unit test to be run from the base dir, or from tests/mues/ or
#	# similar:
#	begin
#		require 'tests/muesunittest'
#	rescue
#		require '../muesunittest'
#	end
#
#	require 'mysomething'
#
#	class MySomethingTest < MUES::TestCase
#		def set_up
#			super()
#			@foo = 'bar'
#		end
#
#		def test_00_something
#			obj = nil
#			assert_nothing_raised { obj = MySomething::new }
#			assert_instance_of MySomething, obj
#			assert_respond_to :myMethod, obj
#		end
#	end
# 
# == Rcsid
# 
#  $Id: muesunittest.rb,v 1.3 2002/09/13 15:36:14 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#
# 

if File.directory? "lib"
	$:.unshift "lib", "ext"
elsif File.directory? "../lib"
	$:.unshift "../lib", "../ext", ".."
end

require "test/unit"

### Test case class
module MUES
	class TestCase < Test::Unit::TestCase

		def ansicode( *codes )
			return "\033[#{codes.collect {|x| sprintf '%02d',x}.join(':')}m"
		end

		### Add a debugging message to the test output if -w is turned on
		def debugMsg( *messages )
			return unless $DEBUG
			$stderr.puts messages.join('')
			$stderr.flush
		end

		### Output a header for delimiting tests
		def testHeader( desc )
			debugMsg( ansicode(1,33) + ">>> " + desc + " <<<" + ansicode(0) )
		end

		### Try to force garbage collection to start.
		def collectGarbage
			a = []
			1000.times { a << {} }
			a = nil
			GC.start
		end

		### Output the name of the test as it's running if in verbose mode.
		def run( result )
			$stderr.puts self.name if $VERBOSE
			super
		end

	end # module TestCase
end # module MUES

