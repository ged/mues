#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for StorableObject
#	$Id: extconf.rb,v 1.4 2002/05/28 15:55:09 stillflame Exp $
#
#

require "mkmf"

$CFLAGS << " -Wall "
dir_config( "StorableObject" )
create_makefile( "StorableObject" )

File.open( "Makefile", "a" ) {|makefile|

	makefile.puts <<-"EOF"

RDOC=/usr/bin/rdoc

rdoc: $(RDOC)
	$(RDOC) --title "StorableObject"

test: $(DLLIB)
	ruby test.rb

	EOF
}


