#!/usr/bin/ruby -w

if $0 =~ /server#{File::Separator}bin#{File::Separator}/
	baseDir = $0.gsub( /server#{File::Separator}bin#{File::Separator}.*/, '' )
	baseDir = '.' if baseDir.empty?
	$: << File.join( baseDir, "lib" )
	DefaultConfigFile = File.join( baseDir, "MUES.cfg" )
else
	DefaultConfigFile = "MUES.cfg"
end

require "mues/ObjectStore"
require "mues/User"
require "mues/Config"

TypeDescriptions = [
	"a regular user",
	"a Creator",
	"an Implementor",
	"an Admin"
]



if ARGV.length > 1
	user = ARGV.shift
	configFile = ARGV.shift || "MUES.cfg"
	config = MUES::Config.new( configFile )
	driver = config['objectstore']['driver']

	puts "Fetching user record for '#{user}' from a #{driver} objectstore."
	os = MUES::ObjectStore.new( config )
	userObj = os.fetchUser( user )

	if userObj.nil?
	puts "No such user '#{user}'."
	else
	puts "User record for user '#{userObj.username}':\n" +
		"\t#{userObj.username.capitalize} is #{TypeDescriptions[userObj.accounttype.to_i]}.\n" +
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
	configFile = ARGV.shift || "MUES.cfg"
	config = MUES::Config.new( configFile )
	os = MUES::ObjectStore.new( config )

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

