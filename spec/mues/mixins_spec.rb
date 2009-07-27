#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rubygems'
require 'spec'
require 'spec/lib/helpers'
require 'spec/lib/constants'

require 'mues/mixins'


include MUES::TestConstants


#####################################################################
###	C O N T E X T S
#####################################################################

describe MUES, "mixins" do
	include MUES::SpecHelpers


	#################################################################
	###	E X A M P L E S
	#################################################################

	describe MUES::HashUtilities do
		it "includes a function for stringifying Hash keys" do
			testhash = {
				:foo => 1,
				:bar => {
					:klang => 'klong',
					:barang => { :kerklang => 'dumdumdum' },
				}
			}

			result = MUES::HashUtilities.stringify_keys( testhash )

			result.should be_an_instance_of( Hash )
			result.should_not be_equal( testhash )
			result.should == {
				'foo' => 1,
				'bar' => {
					'klang' => 'klong',
					'barang' => { 'kerklang' => 'dumdumdum' },
				}
			}
		end


		it "includes a function for symbolifying Hash keys" do
			testhash = {
				'foo' => 1,
				'bar' => {
					'klang' => 'klong',
					'barang' => { 'kerklang' => 'dumdumdum' },
				}
			}

			result = MUES::HashUtilities.symbolify_keys( testhash )

			result.should be_an_instance_of( Hash )
			result.should_not be_equal( testhash )
			result.should == {
				:foo => 1,
				:bar => {
					:klang => 'klong',
					:barang => { :kerklang => 'dumdumdum' },
				}
			}
		end
	end

	describe MUES::ArrayUtilities do
		it "includes a function for stringifying Array elements" do
			testarray = [:a, :b, :c, [:d, :e, [:f, :g]]]

			result = MUES::ArrayUtilities.stringify_array( testarray )

			result.should be_an_instance_of( Array )
			result.should_not be_equal( testarray )
			result.should == ['a', 'b', 'c', ['d', 'e', ['f', 'g']]]
		end


		it "includes a function for symbolifying Array elements" do
			testarray = ['a', 'b', 'c', ['d', 'e', ['f', 'g']]]

			result = MUES::ArrayUtilities.symbolify_array( testarray )

			result.should be_an_instance_of( Array )
			result.should_not be_equal( testarray )
			result.should == [:a, :b, :c, [:d, :e, [:f, :g]]]
		end
	end

	describe MUES::Loggable do

		it "adds a log method to instances of including classes" do
			testclass = Class.new do
				include MUES::Loggable
			end

			testclass.new.should respond_to( :log )
		end

	end


	describe MUES::Configurable do

		before( :each ) do
			@real_configurable_modules = MUES::Configurable.modules
			MUES::Configurable.modules.clear
		end

		after( :each ) do
			MUES::Configurable.modules.replace( @real_configurable_modules )
		end


		it "does not allow extension of non-module objects" do
			lambda {
				"foo".extend( MUES::Configurable )
			}.should raise_error( ArgumentError, /can't make a string configurable/i )
		end


		describe "mixed into a class without an implementation of the API" do

			before( :each ) do
				@configurable_class = Class.new do
					include MUES::Configurable
				end
			end

			it "generates an exception if it's configured" do
				@configurable_class.should respond_to( :configure )
				lambda {
					@configurable_class.configure( nil, nil )
				}.should raise_error( NotImplementedError, 
					/does not implement required method 'configure'/i )
			end

			it "provides a default config key based on the class's name" do
				@configurable_class.should_receive( :name ).at_least( :once ).
					and_return( "MUES::UglyBunny" )
				@configurable_class.config_key.should == :uglybunny
			end

		end

		describe "mixed into a class with additional setup" do

			before( :each ) do
				@configurable_class = Class.new do
					include MUES::Configurable
					config_key :foo

					@config = nil

					def self::configure( config, dispatcher )
						config.passed
						dispatcher.passed
					end
				end
			end

			it "provides a declarative so an including class can set its own key" do
				@configurable_class.config_key.should == :foo
			end

			it "passes config section which corresponds to known modules when passed a config object" do
				engine = mock( "mues engine" )
				config = mock( "config object" )
				foosection = mock( "config section" )

				config.should_receive( :member? ).with( :foo ).and_return( true )
				config.should_receive( :foo ).and_return( foosection )

				foosection.should_receive( :passed )
				engine.should_receive( :passed )

				MUES::Configurable.configure_modules( config, engine )
			end
		end
	end

end


