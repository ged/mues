#!/usr/bin/ruby -w

require "mues/ObjectStore"
require "mues/Player"

RoleDescriptions = [
	"a regular player",
	"a Creator",
	"an Implementor",
	"an Admin"
]


unless ARGV.length.nonzero?
	$stderr.puts "usage: #{$0} <username> [<driver>]"
	exit 1
end

user = ARGV.shift
driver = ARGV.shift || "Mysql"

puts "Fetching player record for '#{user}' from a #{driver} objectstore."
os = MUES::ObjectStore.new( driver, 'mues', 'localhost', 'deveiant', '3l3g4nt' )
player = os.fetchPlayer( user )

if player.nil?
	puts "No such player '#{user}'."
else
	puts "Player record for user '#{player.username}':\n" +
		"\t#{player.username.capitalize} is #{RoleDescriptions[player.role.to_i]}.\n" +
		"\tCreated: #{player.timeCreated.to_s}\n" +
		"\tCrypted password: #{player.cryptedPass}\n" +
		"\tReal name: #{player.realname}\n" +
		"\tEmail address: #{player.emailAddress}\n" +
		"\tLast login: #{player.lastLogin}\n" +
		"\tLast host: #{player.lastHost}\n" +
		"\tFirst login tick: #{player.firstLoginTick}\n" +
		"\tPreferences: \n" + player.preferences.collect {|k,v| "\t\t#{k} => #{v}\n"}.to_s +
		"\tCharacters: \n" + player.characters.collect {|char| "\t\t#{char.name}\n"}.to_s +
		"\n\n"
end


