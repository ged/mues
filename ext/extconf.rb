#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for MUES C Extensions.
#	$Id: extconf.rb,v 1.8 2002/06/08 20:56:43 deveiant Exp $
#
#

require "mkmf"

$CFLAGS << " -Wall -Wno-comment"
dir_config( "mues" )
create_makefile( "mues" )


