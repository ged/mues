#!/usr/bin/ruby
###########################################################################
=begin

=Name

mues.rb - Server startup script

=Synopsis

  $ mues.rb

=Description

A basic non-forking MUES server.

=Author

 Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

 Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

 This module is free software. You may use, modify, and/or redistribute this
 software under the terms of the Perl Artistic License. (See
 http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Engine"
require "mues/Config"

ConfigFile = "MUES.cfg"

### Main function
def main

	### Instantiate the configuration and the server objects
	config = MUES::Config.new( ConfigFile )
	engine = MUES::Engine.instance

	engine.debugLevel = 5

	### Start up and run the server
	puts "Starting up...\n"
	engine.start( config )
	puts "Shut down...\n"
	
end


main
