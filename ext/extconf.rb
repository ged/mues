#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for MUES::PolymorphicObject
#	$Id: extconf.rb,v 1.6 2002/05/28 17:40:08 deveiant Exp $
#
#

require "mkmf"

$CFLAGS << " -Wall "
dir_config( "PolymorphicObject" )
create_makefile( "PolymorphicObject" )


