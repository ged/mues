#!/usr/bin/ruby -w
#
#	Test suite for MUES classes
#
#

$:.unshift "lib"

require 'find'
require 'test/unit/testsuite'
require 'test/unit/ui/console/testrunner'

### Load all the tests from the tests dir
Find.find("tests") {|file|
	Find.prune if file =~ /^.'/ or file =~ /~$/
	Find.prune if file =~ /TEMPLATE/
	next if File.stat( file ).directory?
	next unless file =~ /\.tests.rb$/
	require "#{file}"
}

class MUESTests
	class << self
		def suite
			suite = Test::Unit::TestSuite.new( "Multi-User Environment Server" )

			ObjectSpace.each_object( Class ) {|klass|
				suite.add( klass.suite ) if klass < Test::Unit::TestCase
			}			

			return suite
		end
	end
end

Test::Unit::UI::Console::TestRunner.new( MUESTests ).start




