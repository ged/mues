#!/usr/bin/ruby -w

require "mues/ObjectStore"
require "mues/User"

RoleDescriptions = [
	"a regular user",
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

puts "Fetching user record for '#{user}' from a #{driver} objectstore."
os = MUES::ObjectStore.new( driver, 'mues', 'localhost', 'deveiant', '3l3g4nt' )
user = os.fetchUser( user )

if user.nil?
	puts "No such user '#{user}'."
else
	puts "User record for user '#{user.username}':\n" +
		"\t#{user.username.capitalize} is #{RoleDescriptions[user.role.to_i]}.\n" +
		"\tCreated: #{user.timeCreated.to_s}\n" +
		"\tCrypted password: #{user.cryptedPass}\n" +
		"\tReal name: #{user.realname}\n" +
		"\tEmail address: #{user.emailAddress}\n" +
		"\tLast login: #{user.lastLogin}\n" +
		"\tLast host: #{user.lastHost}\n" +
		"\tFirst login tick: #{user.firstLoginTick}\n" +
		"\tPreferences: \n" + user.preferences.collect {|k,v| "\t\t#{k} => #{v}\n"}.to_s +
		"\n\n"
end


