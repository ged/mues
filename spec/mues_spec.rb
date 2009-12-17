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

	it "knows what version it is" do
		MUES.constants.should include( :VERSION )
		MUES::VERSION.should =~ /\d+\.\d+\.\d+/
	end

end

