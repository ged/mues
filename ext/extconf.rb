#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for MUES::PolymorphicObject
#	$Id: extconf.rb,v 1.7 2002/06/04 06:45:33 deveiant Exp $
#
#

require "mkmf"

$CFLAGS << " -Wall -Wno-comment"
dir_config( "mues" )
create_makefile( "mues" )


