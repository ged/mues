#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for MonadicObject
#	$Id: extconf.rb,v 1.2 2002/02/12 00:44:02 deveiant Exp $
#
#

require "mkmf"

$CFLAGS << " -Wall "
dir_config( "MonadicObject" )
create_makefile( "MonadicObject" )


