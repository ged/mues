#!/usr/bin/ruby -w

require "mues/ObjectStore"
require "mues/User"

unless ARGV.length.nonzero?
	$stderr.puts "usage: #{$0} <username> [<driver>]"
	exit 1
end

user = ARGV.shift
driver = ARGV.shift || "Mysql"

puts "Deleting user record for '#{user}' from a #{driver} objectstore."
os = MUES::ObjectStore.new( driver, 'mues', 'localhost', 'deveiant', '3l3g4nt' )
user = os.deleteUser( user )

puts "User record for #{user} deleted."
