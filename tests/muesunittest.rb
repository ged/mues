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
#  $Id: muesunittest.rb,v 1.7 2002/10/25 05:09:53 deveiant Exp $
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
	$:.unshift "lib", "ext", "tests"
elsif File.directory? "../lib"
	$:.unshift "../lib", "../ext", "tests", ".."
end

require "test/unit"

# Require the mock object lib
require "mock"


### Test case class
module MUES
	class TestCase < Test::Unit::TestCase

		# Set some ANSI escape code constants (Shamelessly stolen from Perl's
		# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
		AnsiAttributes = {
			'clear'      => 0,
			'reset'      => 0,
			'bold'       => 1,
			'dark'       => 2,
			'underline'  => 4,
			'underscore' => 4,
			'blink'      => 5,
			'reverse'    => 7,
			'concealed'  => 8,

			'black'      => 30,   'on_black'   => 40, 
			'red'        => 31,   'on_red'     => 41, 
			'green'      => 32,   'on_green'   => 42, 
			'yellow'     => 33,   'on_yellow'  => 43, 
			'blue'       => 34,   'on_blue'    => 44, 
			'magenta'    => 35,   'on_magenta' => 45, 
			'cyan'       => 36,   'on_cyan'    => 46, 
			'white'      => 37,   'on_white'   => 47
		}

		# ANSI escape to move to the previous line and clear it
		ErasePreviousLine = "\033[A\033[K"


		### Returns a String containing the specified ANSI escapes suitable for
		### inclusion in another string. The <tt>attributes</tt> should be one
		### or more of the keys of AnsiAttributes.
		def ansiCode( *attributes )
			attr = attributes.collect {|a| AnsiAttributes[a] ? AnsiAttributes[a] : nil}.compact.join(';')
			if attr.empty? 
				return ''
			else
				return "\e[%sm" % attr
			end
		end

		### Output the specified <tt>msgs</tt> joined together to
		### <tt>STDOUT</tt>.
		def message( *msgs )
			$stdout.puts msgs.join('')
			$stdout.flush
		end

		### Output the specified <tt>msgs</tt> joined together to
		### <tt>STDERR</tt> if <tt>$DEBUG</tt> is set.
		def debugMsg( *msgs )
			return unless $DEBUG
			$stderr.puts "%sDEBUG>>> %s %s" %
				[ ansiCode('bold', 'red'), msgs.join(''), ansiCode('reset') ]
			$stderr.flush
		end

		### Replace the previous line with the specified <tt>msgs</tt>.
		def replaceMessage( *msgs )
			print ErasePreviousLine
			message( *msg )
		end

		### Output a separator line made up of <tt>length</tt> of the specified
		### <tt>char</tt>.
		def writeLine( length=75, char="-" )
			puts "\r" + (char * length )
		end


		### Output a header for delimiting tests
		def testHeader( desc )
			return unless $VERBOSE || $DEBUG
			message "%s>>> %s <<<%s" % 
				[ ansiCode(%w{bold white on_blue}), desc, ansiCode('reset') ]
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


		### Additional assertion methods

		### Passes if <tt>actual</tt> matches the given <tt>regexp</tt>.
		def assert_match( regexp, actual, message=nil )
			_wrap_assertion {
				assert(regexp.kind_of?(Regexp), "The first parameter to assert_matches should be a Regexp.")
				full_message = build_message(message, actual, regexp) {
					| arg1, arg2 |
					"Expected <#{arg1}> to match #{arg2.inspect}"
				}
				assert_block(full_message) {
					regexp.match( actual )
				}
			}
		end



		### This was copied from test/unit.rb because I can't call it from
		### here. Grrr... one shouldn't make methods useful to subclassers
		### private.

		def _wrap_assertion # :nodoc:
			@_assertion_wrapped ||= false
			if (!@_assertion_wrapped)
				@_assertion_wrapped = true
				begin
					add_assertion
					return yield
				ensure
					@_assertion_wrapped = false
				end
			else    
				return yield
			end
		end

	end # module TestCase
end # module MUES

