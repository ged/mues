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

unless ARGV.length.nonzero?
	$stderr.puts "usage: #{$0} <username> [<driver>]"
	exit 1
end

user = ARGV.shift
configFile = ARGV.shift || "MUES.cfg"
config = MUES::Config.new( configFile )
driver = config['objectstore']['driver']

puts "Deleting user record for '#{user}' from a #{driver} objectstore."
os = MUES::ObjectStore.new( config )
user = os.deleteUser( user )

puts "User record for #{user} deleted."
