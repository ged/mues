#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for MUES C Extensions.
#	$Id$
#
#

require "mkmf"

$CFLAGS << " -Wall -Wno-comment"
$CFLAGS << " -DDEBUG" if $DEBUG
dir_config( "mues_ext" )
create_makefile( "mues_ext" )


