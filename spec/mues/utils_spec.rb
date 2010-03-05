#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'spec/lib/constants'
require 'spec/lib/helpers'

require 'mues'
require 'mues/utils'


include MUES::TestConstants


#####################################################################
###	C O N T E X T S
#####################################################################

describe MUES, "utilities" do
	include MUES::SpecHelpers

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end

end


# vim: set nosta noet ts=4 sw=4:
