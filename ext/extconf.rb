#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for MUES C Extensions.
#	$Id: extconf.rb,v 1.9 2003/04/19 06:50:48 deveiant Exp $
#
#

require "mkmf"

$CFLAGS << " -Wall -Wno-comment"
$CFLAGS << " -DDEBUG" if $DEBUG
dir_config( "mues" )
create_makefile( "mues" )


