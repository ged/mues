#!/usr/bin/ruby
#
#	Test suite for MUES classes
#
#

BEGIN {
	$:.unshift "lib", "ext", "tests"

	require "mues/Log"
	require "log4r"
	require "log4r/outputter/fileoutputter"
	MUES::Log::mueslogger.outputters =
		Log4r::FileOutputter::new( 'logfile',
								  :filename => 'test.log',
								  :trunc => true )

	# Workaround for the sprintf error that shows up in the simpleformatter in
	# later versions of Ruby 1.7.3.
	Log4r::Outputter['logfile'].formatter =
		Log4r::PatternFormatter::new( :pattern => '[%d] [%l] %C: %.1024m',
									  :date_pattern => '%Y/%m/%d %H:%M:%S %Z' )
	
}

require './utils'
include UtilityFunctions

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
	debugMsg "Requiring '%s'..." % file
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




