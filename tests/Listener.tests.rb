#!/usr/bin/ruby -w

# This tests not only the Listener code itself, but also the Factory
# mixin, as Listener uses it to allow creation of its subclasses through itself.

unless defined? MUES && defined? MUES::TestCase
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )

	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/ext" unless
		$LOAD_PATH.include?( "#{basedir}/ext" )
	$LOAD_PATH.unshift "#{basedir}/tests" unless
		$LOAD_PATH.include?( "#{basedir}/tests" )

	require 'muestestcase'
end

require 'test/unit/mock'
require 'mues/listener'

class MUES::ListenerTestCase < MUES::TestCase

	Derivatives = %w[
		Telnet
		Socket
		Console
	]

	Params = {
		:test	=> true,
		:questionnaire => nil,
	}

	MockOutputFilter = Test::Unit::MockObject( MUES::OutputFilter )


	### Test class + instantiation
	def test_00_Instance
		printTestHeader "Listener: Instantiation"

		assert_instance_of Class, MUES::Listener
		assert MUES::Listener < PluginFactory, "Listener < PluginFactory"

		assert_raises( MUES::InstantiationError ) {
			MUES::Listener::new
		}
	end

	### Test generalization
	def test_10_Derivatives
		printTestHeader "Listener: Derivatives"
		testClass, rval = nil, nil

		assert_nothing_raised( "Creating derivative class" ) {
			testClass = Class::new( MUES::Listener )
		}

		assert_nothing_raised( "Instantiating derivative class" ) {
			rval = testClass.new( "test" )
		}
		assert_kind_of MUES::Listener, rval
	end

	### Test factory method
	def test_20_FactoryMethod
		printTestHeader "Listener: Factory Method"
		rval = nil

		Derivatives.each {|name|

			# A named listener without parameters
			assert_nothing_raised( "Instantiate a '#{name}' Listener" ) {
				rval = MUES::Listener::create( name, name )
			}

			assert_kind_of MUES::Listener, rval
			assert_nothing_raised {
				rval.stop
			}

			# A named listener with parameters
			assert_nothing_raised( "Instantiate a '#{name}' Listener" ) {
				rval = MUES::Listener::create( name, name, Params )
			}

			assert_kind_of MUES::Listener, rval
			assert_nothing_raised {
				rval.stop
			}
		}
	end

	# Utility method to create a sequence of listeners to test, all on different
	# ports.
	def createListeners
		port = 4848
		listeners = {}
		Derivatives.each {|name|
			port += 1
			listeners[ name ] = 
				MUES::Listener::create( name, name, Params.merge(:bindPort => port) )
		}

		if block_given?
			begin
				yield( listeners )
			ensure
				listeners.each {|name,list|
					list.stop
				}
			end
		else
			return listeners
		end
	end


	### Test name
	def test_30_Name
		printTestHeader "Listener: Name"
		rval = nil

		self.createListeners do |listeners|
			listeners.each {|name, listener|
				assert_nothing_raised { rval = listener.name }
				assert_equal name, rval
			}
		end
	end


	### Test config parameters
	def test_40_Parameters
		printTestHeader "Listener: Parameters"
		rval = nil

		self.createListeners do |listeners|
			listeners.each {|name, listener|
				assert_nothing_raised { rval = listener.params }
				assert_instance_of Hash, rval
				assert_equal true, rval[:test]

				# Test the alias, too
				assert_nothing_raised { rval = listener.parameters }
				assert_instance_of Hash, rval
				assert_equal true, rval[:test]
			}
		end
	end


	### Make sure each listener has an IO
	def test_50_IO
		printTestHeader "Listener: IO"
		rval = nil

		self.createListeners do |listeners|
			listeners.each {|name, listener|
				assert_nothing_raised { rval = listener.io }
				assert_kind_of IO, rval
			}
		end
	end


	### Test the filter debug level
	def test_60_Filter_Debug_Level
		printTestHeader "Listener: Filter debug level"
		rval = nil

		self.createListeners do |listeners|
			listeners.each {|name, listener|
				msg = "with #{name} Listener:"
				assert_nothing_raised( msg ) {
					rval = listener.filterDebugLevel
				}
				assert_instance_of Fixnum, rval, msg

				assert_nothing_raised( msg ) { listener.filterDebugLevel = 5 }
				assert_equal 5, listener.filterDebugLevel, msg
			}
		end
	end


	### Initial filters
	def test_70_Initial_Filters
		printTestHeader "Listener: Filter debug level"
		rval = nil

		self.createListeners do |listeners|
			listeners.each {|name, listener|
				msg = "with #{name} listener"
				ofilter = MockOutputFilter::new

				assert_raises( ArgumentError, msg ) {
					listener.getInitialFilters
				}
				assert_nothing_raised {
					rval = listener.getInitialFilters( ofilter )
				}
				assert_instance_of Array, rval, msg
			}
		end
	end

end # class MUES::ListenerTestCase

