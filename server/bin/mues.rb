#!/usr/bin/ruby
#
#	Monolithic Server Thingie
#
#
#
#

require "mues/Config"
require "mues/Engine"

$ConfigFile = "MUES.cfg"

### Main function
def main

	### Instantiate the configuration and the server objects
	config = MUES::Config.new( $ConfigFile )
	engine = MUES::Engine.instance

	### Start up and run the server
	puts "Starting up...\n"
	engine.start( config )
	puts "Shut down...\n"
	
end


main
