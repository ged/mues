#!/usr/bin/ruby -w

# This tests not only the Listener code itself, but also the FactoryMethods
# mixin, as Listener uses it to allow creation of its subclasses through itself.

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
end

require 'mues/listener'

class MUES::ListenerTestCase < MUES::TestCase

	Derivatives = %w[
		Telnet
		Socket
		Console
	]

	### Test class + instantiation
	def test_00_Instance
		printTestHeader "Listener: Instantiation"

		assert_instance_of Class, MUES::Listener
		assert MUES::Listener < MUES::FactoryMethods, "Listener < FactoryMethods"

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
			assert_nothing_raised( "Instantiate a '#{name}' Listener" ) {
				rval = MUES::Listener::create( name, name )
			}

			assert_kind_of MUES::Listener, rval
			assert_nothing_raised {
				rval.stop
			}
		}
	end

end # class MUES::ListenerTestCase

