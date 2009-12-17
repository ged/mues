
BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'spec'
require 'spec/lib/helpers'
require 'spec/lib/constants'

require 'mues/engine.rb'



#####################################################################
###	C O N T E X T S
#####################################################################

describe MUES::Engine do
	include MUES::SpecHelpers,
	        MUES::TestConstants

	

end

