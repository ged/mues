#!/usr/bin/ruby -w

require "mues/ObjectStore"
require "mues/User"

RoleDescriptions = [
	"a regular user",
	"a Creator",
	"an Implementor",
	"an Admin"
]

DefaultDriver = 'Mysql'


if ARGV.length > 1
	user = ARGV.shift
	driver = ARGV.shift || DefaultDriver

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

else
	driver = ARGV.shift || DefaultDriver
	os = MUES::ObjectStore.new( driver, 'mues', 'localhost', 'deveiant', '3l3g4nt' )

	list = os.getUserList

	if list.empty? 
		puts "No users found"
	else
		puts "User list:"
		list.each {|username|
			puts "  #{username}"
		}
	end
end

