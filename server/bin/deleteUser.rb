#!/usr/bin/ruby -w

require "mues/ObjectStore"
require "mues/Player"

unless ARGV.length.nonzero?
	$stderr.puts "usage: #{$0} <username> [<driver>]"
	exit 1
end

user = ARGV.shift
driver = ARGV.shift || "Mysql"

puts "Deleting player record for '#{user}' from a #{driver} objectstore."
os = MUES::ObjectStore.new( driver, 'mues', 'localhost', 'deveiant', '3l3g4nt' )
player = os.deletePlayer( user )

puts "Player record for #{user} deleted."
