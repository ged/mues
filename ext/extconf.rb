#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for MonadicObject
#
#

require "mkmf"

$CFLAGS << " -Wall "
dir_config( "MonadicObject" )

# Write the Makefile
create_makefile( "MonadicObject" )

# Add the 'depend' target to the end of the Makefile
File.open( "Makefile", "a" ) {|make|
	make.print <<-EOF

depend:
	$(CC) $(CFLAGS) $(CPPFLAGS) -MM *.c > depend

EOF
}


