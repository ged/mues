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
	userObj = os.fetchUser( user )

	if userObj.nil?
	puts "No such user '#{user}'."
	else
	puts "User record for user '#{userObj.username}':\n" +
		"\t#{userObj.username.capitalize} is #{RoleDescriptions[userObj.role.to_i]}.\n" +
		"\tCreated: #{userObj.timeCreated.to_s}\n" +
		"\tCrypted password: #{userObj.cryptedPass}\n" +
		"\tReal name: #{userObj.realname}\n" +
		"\tEmail address: #{userObj.emailAddress}\n" +
		"\tLast login: #{userObj.lastLogin}\n" +
		"\tLast host: #{userObj.lastHost}\n" +
		"\tFirst login tick: #{userObj.firstLoginTick}\n" +
		"\tPreferences: \n" + userObj.preferences.collect {|k,v| "\t\t#{k} => #{v}\n"}.to_s +
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

