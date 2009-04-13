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
#		require 'tests/muestestcase'
#	rescue
#		require '../muestestcase'
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
# == Subversion ID
# 
# $Id$
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

begin
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )

	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/ext" unless
		$LOAD_PATH.include?( "#{basedir}/ext" )
	$LOAD_PATH.unshift "#{basedir}/tests" unless
		$LOAD_PATH.include?( "#{basedir}/tests" )
end

require 'rubygems'
gem 'test-unit-mock'

require "test/unit"
require "test/unit/mock"

require "mues"

module MUES

	### The abstract base class for MUES test cases.
	class TestCase < Test::Unit::TestCase

		@setupBlocks = []
		@teardownBlocks = []

		class << self
			@methodCounter = 0
			attr_accessor :methodCounter, :setupBlocks, :teardownBlocks
		end


		### Inheritance callback -- adds @setupBlocks and @teardownBlocks ivars
		### and accessors to the inheriting class.
		def self::inherited( klass )
			klass.module_eval {
				@setupBlocks = []
				@teardownBlocks = []

				class << self
					attr_accessor :setupBlocks
					attr_accessor :teardownBlocks
				end
			}
			klass.methodCounter = 0
		end
		


		### Output the specified <tt>msgs</tt> joined together to
		### <tt>STDERR</tt> if <tt>$DEBUG</tt> is set.
		def self::debugMsg( *msgs )
			return unless $DEBUG
			self.message "DEBUG>>> %s" % msgs.join('')
		end

		### Output the specified <tt>msgs</tt> joined together to
		### <tt>STDOUT</tt>.
		def self::message( *msgs )
			$stderr.puts msgs.join('')
			$stderr.flush
		end


		### Add a setup block for the current testcase
		def self::addSetupBlock( &block )
			self.methodCounter += 1
			newMethodName = "setup_#{self.methodCounter}".intern
			define_method( newMethodName, &block )
			self.setupBlocks.push newMethodName
		end
			
		### Add a teardown block for the current testcase
		def self::addTeardownBlock( &block )
			self.methodCounter += 1
			newMethodName = "teardown_#{self.methodCounter}".intern
			define_method( newMethodName, &block )
			self.teardownBlocks.unshift newMethodName
		end
			

		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Forward-compatibility method for namechange in Test::Unit
		def setup( *args )
			self.class.setupBlocks.each {|sblock|
				debugMsg "Calling setup block method #{sblock}"
				self.send( sblock )
			}
			super( *args )
		end
		alias_method :set_up, :setup


		### Forward-compatibility method for namechange in Test::Unit
		def teardown( *args )
			super( *args )
			self.class.teardownBlocks.each {|tblock|
				debugMsg "Calling teardown block method #{tblock}"
				self.send( tblock )
			}
		end
		alias_method :tear_down, :teardown


		### Turn off the stupid 'No tests were specified'
		def default_test; end


		### Instance alias for the like-named class method.
		def addSetupBlock( &block )
			self.class.addSetupBlock( &block )
		end


		### Instance alias for the like-named class method.
		def addTeardownBlock( &block )
			self.class.addTeardownBlock( &block )
		end


		### Instance alias for the like-named class method.
		def message( *msgs )
			self.class.message( *msgs )
		end


		### Instance alias for the like-named class method
		def debugMsg( *msgs )
			self.class.debugMsg( *msgs )
		end


		### Output a separator line made up of <tt>length</tt> of the specified
		### <tt>char</tt>.
		def writeLine( length=75, char="-" )
			$stderr.puts "\r" + (char * length )
		end


		### Output a header for delimiting tests
		def printTestHeader( desc )
			return unless $VERBOSE || $DEBUG
			message ">>> %s <<<" % desc
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
			$stderr.puts self.name if $VERBOSE || $DEBUG

			# Support debugging for individual tests
			olddb = nil
			if $DebugPattern && $DebugPattern =~ @method_name
				MUES::Logger::global.outputters <<
					MUES::Logger::Outputter::create( 'file', $stderr, "STDERR" )
				MUES::Logger::global.level = :debug

				olddb = $DEBUG
				$DEBUG = true
			end
			
			super

			unless olddb.nil?
				$DEBUG = olddb 
				MUES::Logger::global.outputters.clear
			end
		end


		#############################################################
		###	E X T R A   A S S E R T I O N S
		#############################################################

		### Override the stupid deprecated #assert_not_nil so when it
		### disappears, code doesn't break.
		def assert_not_nil( obj, msg=nil )
			msg ||= "<%p> expected to not be nil." % obj
			assert_block( msg ) { !obj.nil? }
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_not_nil/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end
		

		### Negative of assert_respond_to
		def assert_not_respond_to( obj, meth )
			msg = "%s expected NOT to respond to '%s'" %
				[ obj.inspect, meth ]
			assert_block( msg ) {
				!obj.respond_to?( meth )
			}
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_not_respond_to/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end


		### Assert that the instance variable specified by +sym+ of an +object+
		### is equal to the specified +value+. The '@' at the beginning of the
		### +sym+ will be prepended if not present.
		def assert_ivar_equal( value, object, sym )
			sym = "@#{sym}".intern unless /^@/ =~ sym.to_s
			msg = "Instance variable '%s'\n\tof <%s>\n\texpected to be <%s>\n" %
				[ sym, object.inspect, value.inspect ]
			msg += "\tbut was: <%s>" % object.instance_variable_get(sym)
			assert_block( msg ) {
				value == object.instance_variable_get(sym)
			}
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_ivar_equal/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end


		### Assert that the specified +object+ has an instance variable which
		### matches the specified +sym+. The '@' at the beginning of the +sym+
		### will be prepended if not present.
		def assert_has_ivar( sym, object )
			sym = "@#{sym}" unless /^@/ =~ sym.to_s
			msg = "Object <%s> expected to have an instance variable <%s>" %
				[ object.inspect, sym ]
			assert_block( msg ) {
				object.instance_variables.include?( sym.to_s )
			}
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_has_ivar/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end


		### Test Hashes for equivalent content
		def assert_hash_equal( expected, actual, msg="" )
			errmsg = "Expected hash <%p> to be equal to <%p>" % [expected, actual]
			errmsg += ": #{msg}" unless msg.empty?

			assert_block( errmsg ) {
				diffs = compare_hashes( expected, actual )
				unless diffs.empty?
					errmsg += ": " + diffs.join("; ")
					return false
				else
					return true
				end
			}
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_hash_equal/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end


		### Compare two hashes for content, returning a list of their differences as
		### descriptions. An empty Array return-value means they were the same.
		def compare_hashes( hash1, hash2, subkeys=nil )
			diffs = []
			seenKeys = []

			hash1.each {|k,v|
				if !hash2.key?( k )
					diffs << "missing %p pair" % k
				elsif hash1[k].is_a?( Hash ) && hash2[k].is_a?( Hash )
					diffs.push( compare_hashes(hash1[k], hash2[k]) )
				elsif hash2[k] != hash1[k]
					diffs << "value for %p expected to be %p, but was %p" %
						[ k, hash1[k], hash2[k] ]
				else
					seenKeys << k
				end
			}

			extraKeys = (hash2.keys - hash1.keys)
			diffs << "extra key/s: #{extraKeys.join(', ')}" unless extraKeys.empty?

			return diffs.flatten
		end


		### Test Hashes (or any other objects with a #keys method) for key set
		### equality
		def assert_same_keys( expected, actual, msg="" )
			errmsg = "Expected keys of <%p> to be equal to those of <%p>" %
				[ actual, expected ]
			errmsg += ": #{msg}" unless msg.empty?

			ekeys = expected.keys; akeys = actual.keys
			assert_block( errmsg ) {
				diffs = []

				# XOR the arrays and make a diff for each one
				((ekeys + akeys) - (ekeys & akeys)).each do |key|
					if ekeys.include?( key )
						diffs << "missing key %p" % [key]
					else
						diffs << "extra key %p" % [key]
					end
				end

				unless diffs.empty?
					errmsg += "\n" + diffs.join("; ")
					return false
				else
					return true
				end
			}
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_hash_equal/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end


		### Succeeds if +obj+ include? +item+.
		def assert_include( item, obj, msg=nil )
			msg ||= "<%p> expected to include <%p>." % [ obj, item ]
			assert_block( msg ) { obj.respond_to?(:include?) && obj.include?(item) }
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_include/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end


		### Succeeds if +obj+ is tainted
		def assert_tainted( obj, msg=nil )
			msg ||= "<%p> expected to be tainted" % [ obj ]
			assert_block( msg ) {
				obj.tainted?
			}
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_tainted/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end


		### Succeeds if +obj+ is not tainted
		def assert_not_tainted( obj, msg=nil )
			msg ||= "<%p> expected to NOT be tainted" % [ obj ]
			assert_block( msg ) {
				!obj.tainted?
			}
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_not_tainted/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end


		### Assert that the specified +str+ does *not* match the given regular
		### expression +re+.
		def assert_not_match( re, str )
			msg = "<%s> expected not to match %p" %
				[ str, re ]
			assert_block( msg ) {
				!re.match( str )
			}
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_not_match/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end


		### Assert that the specified +klass+ defines the specified instance
		### method +meth+.
		def assert_has_instance_method( klass, meth )
			msg = "<%s> expected to define instance method #%s" %
				[ klass, meth ]
			assert_block( msg ) {
				klass.instance_methods.include?( meth.to_s )
			}
		rescue Test::Unit::AssertionFailedError => err
			cutframe = err.backtrace.reverse.find {|frame|
				/assert_has_instance_method/ =~ frame
			}
			firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
			Kernel::raise( err, err.message, err.backtrace[firstIdx..-1] )
		end

	end # class TestCase

end # module MUES

