#!/usr/bin/ruby -w

# This is a script that I'm using to help sort out the bugs in
# MUES::CommandShell::Factory and the command parser.

if ! File.directory?( "lib" )
	if File.directory?( "../lib" ) && File.directory?( "../lib/mues" )
		myself = File::expand_path( __FILE__ )
		Dir.chdir( ".." ) { Kernel::load(myself) }
		exit
	end

	raise Exception, "Can't find the MUES lib directory"
end

$LOAD_PATH.unshift "lib", "ext"
require 'mues'

puts "Creating config object"
c = MUES::Config::new

puts "Creating CommandShell factory"
csf = MUES::CommandShell::Factory::new( c )

puts "Commands loaded: "
csf.registry.values.each {|cmd| puts "  #{cmd.inspect}"}



