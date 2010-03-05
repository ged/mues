#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"
	extdir = basedir + "ext"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
	$LOAD_PATH.unshift( extdir ) unless $LOAD_PATH.include?( extdir )
}

require 'spec'
require 'spec/lib/constants'
require 'spec/lib/helpers'

require 'mues'


include MUES::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################

describe MUES do
	include MUES::SpecHelpers

	it "should know if its default logger is replaced" do
		MUES.reset_logger
		MUES.should be_using_default_logger
		MUES.logger = Logger.new( $stderr )
		MUES.should_not be_using_default_logger
	end


	it "returns a version string if asked" do
		MUES.version_string.should =~ /\w+ [\d.]+/
	end


	it "returns a version string with a build number if asked" do
		MUES.version_string(true).should =~ /\w+ [\d.]+ \(build [[:xdigit:]]+\)/
	end


	describe " logging subsystem" do
		before(:each) do
			MUES.reset_logger
		end

		after(:each) do
			MUES.reset_logger
		end


		it "has the default logger instance after being reset" do
			MUES.logger.should equal( MUES.default_logger )
		end

		it "has the default log formatter instance after being reset" do
			MUES.logger.formatter.should equal( MUES.default_log_formatter )
		end

	end


	describe " logging subsystem with new defaults" do
		before( :all ) do
			@original_logger = MUES.default_logger
			@original_log_formatter = MUES.default_log_formatter
		end

		after( :all ) do
			MUES.default_logger = @original_logger
			MUES.default_log_formatter = @original_log_formatter
		end


		it "uses the new defaults when the logging subsystem is reset" do
			logger = mock( "dummy logger", :null_object => true )
			formatter = mock( "dummy logger" )

			MUES.default_logger = logger
			MUES.default_log_formatter = formatter

			logger.should_receive( :formatter= ).with( formatter )

			MUES.reset_logger
			MUES.logger.should equal( logger )
		end

	end

end

