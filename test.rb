#!/usr/bin/ruby
#
#	Test suite for MUES classes
#
#

$:.unshift "lib", "tests"

require 'find'
require 'test/unit'
require 'test/unit/testsuite'
require 'test/unit/ui/console/testrunner'

patterns = []
ARGV.each {|pat| patterns << Regexp::new( pat )}

requires = []

### Load all the tests from the tests dir
Find.find("tests") {|file|
	Find.prune if file =~ /^.'/ or file =~ /~$/
	Find.prune if file =~ /TEMPLATE/
	next if File.stat( file ).directory?

 	unless patterns.empty?
 		Find.prune unless patterns.find {|pat| pat =~ file}
 	end

	next unless file =~ /\.tests.rb$/
	require "#{file}"
	requires << file
}

$stderr.puts "Required #{requires.length} files."
unless patterns.empty?
	$stderr.puts "[" + requires.sort.join( ", " ) + "]"
end

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




