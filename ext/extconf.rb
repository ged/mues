#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for StorableObject
#	$Id: extconf.rb,v 1.5 2002/05/28 16:44:16 deveiant Exp $
#
#

require "mkmf"

$CFLAGS << " -Wall "
dir_config( "StorableObject" )
create_makefile( "StorableObject" )


