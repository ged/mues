#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'mues'
require 'mues/logger'

require 'spec/lib/constants'
require 'spec/lib/helpers'


include MUES::TestConstants

# Testing class
class MUES::Object; end


#####################################################################
###	C O N T E X T S
#####################################################################

describe MUES::Logger do
	include MUES::SpecHelpers

	before( :each ) do
		MUES::Logger.reset
	end

	after( :all ) do
		MUES::Logger.reset
	end


	it "has a global anonymous singleton instance" do
		MUES::Logger.global.should be_an_instance_of( MUES::Logger )
		MUES::Logger.global.module.should == Object
	end


	it "writes every message to the global logger" do
		outputter = mock( "logging outputter" )

		MUES::Logger.global.outputters << outputter

		outputter.should_receive( :write ).with( duck_type(:strftime), :debug, "(global)", nil, "test message" )

		MUES::Logger.global.level = :debug
		MUES::Logger.global.debug "test message"
	end


	it "doesn't output a message if its level is less than the level set in the logger" do
		outputter = mock( "logging outputter" )

		MUES::Logger.global.outputters << outputter

		outputter.should_not_receive( :write ).
			with( duck_type(:strftime), :debug, "(global)", nil, "debug message" )
		outputter.should_receive( :write ).
			with( duck_type(:strftime), :info, "(global)", nil, "info message" )

		MUES::Logger.global.level = :info
		MUES::Logger.global.debug "debug message"
		MUES::Logger.global.info "info message"
	end


	it "creates loggers for specific classes via its index operator" do
		klass = Class.new
		MUES::Logger[ klass ].should be_an_instance_of( MUES::Logger )
		MUES::Logger[ klass ].should_not == MUES::Logger.global
	end


	it "propagates log messages from class-specific loggers to the global logger" do
		outputter = mock( "logging outputter" )
		classoutputter = mock( "outputter for a class" )

		klass = Class.new

		MUES::Logger.global.outputters << outputter
		MUES::Logger.global.level = :info

		MUES::Logger[ klass ].outputters << classoutputter
		MUES::Logger[ klass ].level = :info

		outputter.should_receive( :write ).
			with( duck_type(:strftime), :info, klass.inspect, nil, "test message" )
		classoutputter.should_receive( :write ).
			with( duck_type(:strftime), :info, klass.inspect, nil, "test message" )

		MUES::Logger[ klass ].info "test message"
	end


	it "propagates log messages from specific class loggers to more-general ones" do
		outputter = mock( "logging outputter" )
		classoutputter = mock( "outputter for a class" )
		subclassoutputter = mock( "outputter for a subclass" )

		klass = Class.new
		subclass = Class.new( klass )

		MUES::Logger.global.outputters << outputter
		MUES::Logger.global.level = :info

		MUES::Logger[ klass ].outputters << classoutputter
		MUES::Logger[ klass ].level = :info

		MUES::Logger[ subclass ].outputters << subclassoutputter
		MUES::Logger[ subclass ].level = :info

		outputter.should_receive( :write ).
			with( duck_type(:strftime), :info, subclass.inspect, nil, "test message" )
		classoutputter.should_receive( :write ).
			with( duck_type(:strftime), :info, subclass.inspect, nil, "test message" )
		subclassoutputter.should_receive( :write ).
			with( duck_type(:strftime), :info, subclass.inspect, nil, "test message" )

		MUES::Logger[ subclass ].info "test message"
	end

	it "never writes a message more than once to an outputter, even it it's set on more than " +
	   "one logger in the hierarchy" do
		outputter = mock( "logging outputter" )

		klass = Class.new
		subclass = Class.new( klass )

		MUES::Logger.global.outputters << outputter
		MUES::Logger.global.level = :info

		MUES::Logger[ klass ].outputters << outputter
		MUES::Logger[ klass ].level = :info

		MUES::Logger[ subclass ].outputters << outputter
		MUES::Logger[ subclass ].level = :info

		outputter.should_receive( :write ).once.
			with( duck_type(:strftime), :info, subclass.inspect, nil, "test message" )

		MUES::Logger[ subclass ].info "test message"
	end


	it "can look up a logger by class name" do
		MUES::Logger[ "MUES::Object" ].should be_equal( MUES::Logger[MUES::Object] )
	end


	it "can look up a logger by an instance of a class" do
		MUES::Logger[ MUES::Object.new ].should be_equal( MUES::Logger[MUES::Object] )
	end


	it "can return a readable name for the module which it logs for" do
		MUES::Logger[ MUES::Object ].readable_name.should == 'MUES::Object'
	end

	it "can return a readable name for the module which it logs for, even if it's an anonymous class" do
		klass = Class.new
		MUES::Logger[ klass ].readable_name.should == klass.inspect
	end

	it "can return a readable name for the global logger" do
		MUES::Logger.global.readable_name.should == '(global)'
	end


	it "can return its current level as a Symbol" do
		MUES::Logger.global.level = :notice
		MUES::Logger.global.readable_level.should == :notice
	end


	it "knows which loggers are for more-general classes" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )

		MUES::Logger[ class3 ].hierloggers.should == [
			MUES::Logger[class3],
			MUES::Logger[class2],
			MUES::Logger[mod],
			MUES::Logger[class1],
			MUES::Logger.global,
		]
	end

	it "knows which loggers are for more-general classes that are of the specified level or lower" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )

		MUES::Logger[ class2 ].level = :debug

		MUES::Logger[ class3 ].hierloggers( :debug ).should == [
			MUES::Logger[class2],
		]
	end

	it "can yield loggers for more-general classes" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )

		loggers = []

		MUES::Logger[ class3 ].hierloggers do |l|
			loggers << l
		end

		loggers.should == [
			MUES::Logger[class3],
			MUES::Logger[class2],
			MUES::Logger[mod],
			MUES::Logger[class1],
			MUES::Logger.global,
		]
	end

	it "knows which outputters are for more-general classes" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )

		outputter1 = stub( "class2's outputter" )
		MUES::Logger[class2].outputters << outputter1
		outputter2 = stub( "mod's outputter" )
		MUES::Logger[mod].outputters << outputter2

		MUES::Logger[ class3 ].hieroutputters.should == [
			outputter1,
			outputter2,
		]
	end

	it "can yield outputters for more-general classes" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )

		outputter1 = stub( "class2's outputter" )
		MUES::Logger[class2].outputters << outputter1
		outputter2 = stub( "mod's outputter" )
		MUES::Logger[mod].outputters << outputter2

		outputters = []
		MUES::Logger[ class3 ].hieroutputters do |outp, logger|
			outputters << outp
		end

		outputters.should == [
			outputter1,
			outputter2,
		]
	end


	it "includes an exception's backtrace if it is set at the log message" do
		outputter = mock( "outputter" )
		MUES::Logger.global.outputters << outputter

		outputter.should_receive( :write ).
			with( duck_type(:strftime), :error, "(global)", nil, %r{Glah\.:\n    } )

		begin
			raise "Glah."
		rescue => err
			MUES::Logger.global.error( err )
		end
	end


	it "can parse a single-word log setting" do
		MUES::Logger.parse_log_setting( 'debug' ).should == [ :debug, nil ]
	end

	it "can parse a two-word log setting" do
		level, uri = MUES::Logger.parse_log_setting( 'info apache' )

		level.should == :info
		uri.should be_an_instance_of( URI::Generic )
		uri.path.should == 'apache'
	end

	it "can parse a word+uri log setting" do
		uristring = 'error dbi://www:password@localhost/www.errorlog?driver=postgresql'
		level, uri = MUES::Logger.parse_log_setting( uristring )

		level.should == :error
		uri.should be_an_instance_of( URI::Generic )
		uri.scheme.should == 'dbi'
		uri.user.should == 'www'
		uri.password.should == 'password'
		uri.host.should == 'localhost'
		uri.path.should == '/www.errorlog'
		uri.query.should == 'driver=postgresql'
	end


	it "resets the level of any message written to it if its forced_level attribute is set" do
		klass = Class.new
		outputter = mock( "outputter" )
		globaloutputter = mock( "global outputter" )

		MUES::Logger[ klass ].level = :info
		MUES::Logger[ klass ].forced_level = :debug
		MUES::Logger[ klass ].outputters << outputter

		MUES::Logger.global.level = :debug
		MUES::Logger.global.outputters << globaloutputter

		outputter.should_not_receive( :write )
		globaloutputter.should_receive( :write ).
			with( duck_type(:strftime), :debug, klass.inspect, nil, 'Some annoying message' )

		MUES::Logger[ klass ].info( "Some annoying message" )
	end

end

# vim: set nosta noet ts=4 sw=4:
