#!/usr/bin/ruby
#
#	Test suite for MUES classes
#
#

BEGIN {
	$:.unshift "lib", "ext", "tests"

	require './utils'
	include UtilityFunctions

	verboseOff {
		require "mues/log"
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
}

verboseOff {
	require 'muestestcase'
	require 'find'
	require 'test/unit'
	require 'test/unit/testsuite'
	require 'test/unit/ui/console/testrunner'
	require 'optparse'
}

# Turn off output buffering
$stderr.sync = $stdout.sync = true

# Initialize variables
safelevel = 0
patterns = []
requires = []

# Parse command-line switches
ARGV.options {|oparser|
	oparser.banner = "Usage: #$0 [options] [TARGETS]\n"

	oparser.on( "--debug", "-d", TrueClass, "Turn debugging on" ) {
		$DEBUG = true
		debugMsg "Turned debugging on."
	}

	oparser.on( "--verbose", "-v", TrueClass, "Make progress verbose" ) {
		$VERBOSE = true
		debugMsg "Turned verbose on."
	}

	# Handle the 'help' option
	oparser.on( "--help", "-h", "Display this text." ) {
		$stderr.puts oparser
		exit!(0)
	}

	oparser.parse!
}

# Parse test patterns
ARGV.each {|pat| patterns << Regexp::new( pat, Regexp::IGNORECASE )}
$stderr.puts "#{patterns.length} patterns given on the command line"

### Load all the tests from the tests dir
Find.find("tests") {|file|
	Find.prune if /\/\./ =~ file or /~$/ =~ file
	Find.prune if /TEMPLATE/ =~ file
	next if File.stat( file ).directory?

 	unless patterns.empty?
 		Find.prune unless patterns.find {|pat| pat =~ file}
 	end

	debugMsg "Considering '%s': " % file
	next unless file =~ /\.tests.rb$/
	debugMsg "Requiring '%s'..." % file
	require "#{file}"
	requires << file
}

$stderr.puts "Required #{requires.length} files."
unless patterns.empty?
	$stderr.puts "[" + requires.sort.join( ", " ) + "]"
end

# Build the test suite
class MUESTests
	class << self
		def suite
			suite = Test::Unit::TestSuite.new( "MUES" )

			if suite.respond_to?( :add )
				ObjectSpace.each_object( Class ) {|klass|
					suite.add( klass.suite ) if klass < MUES::TestCase
				}
			else
				ObjectSpace.each_object( Class ) {|klass|
					suite << klass.suite if klass < MUES::TestCase
				}			
			end

			return suite
		end
	end
end

# Run tests
$SAFE = safelevel
MUES::Log.mueslogger.level = 0 if $DEBUG
Test::Unit::UI::Console::TestRunner.new( MUESTests ).start

$stderr.puts "Done with tests" if $VERBOSE

