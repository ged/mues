#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for PolymorphicObject
#	$Id: extconf.rb,v 1.3 2002/02/15 07:33:24 deveiant Exp $
#
#

require "mkmf"

$CFLAGS << " -Wall "
dir_config( "PolymorphicObject" )
create_makefile( "PolymorphicObject" )

File.open( "Makefile", "a" ) {|makefile|

	makefile.puts <<-"EOF"

RDOC=/usr/bin/rdoc

rdoc: $(RDOC)
	$(RDOC) --title "PolymorphicObject"

test: $(DLLIB)
	ruby test.rb

	EOF
}


