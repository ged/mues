#!/usr/bin/ruby -w

require "readline"
require "mues/Player"
require "mues/ObjectStore"

include Readline

def main
	unless ARGV.length.nonzero? && ARGV[0] =~ /^\w{3,}$/
		$stderr.puts "usage: #{$0} <username> [<driver>]"
		exit 1
	end

	user = ARGV.shift
	driver = ARGV.shift || "Mysql"

	puts "Creating player record for '#{user}' in a #{driver} objectstore."
	os = MUES::ObjectStore.new( driver, 'mues', 'localhost', 'deveiant', '3l3g4nt' )
	player = os.createPlayer( user )

	player.password = prompt( "Password" )
	player.realname = prompt( "Real name" )
	player.emailAddress = prompt( "Email" )

	player.role = promptForRole()

	print "Storing new player record:"
	os.storePlayer( player )
	puts "done."

	puts player.inspect
end

def prompt( promptString )
	promptString.chomp!
	return readline( "#{promptString}: " ).strip
end

def promptForRole
	role = nil
	roles = MUES::Player::Role.constants.collect {|s| s.downcase}
	oldCp = Readline.completion_proc = Proc.new {|str|
		roles.find_all {|rolename| rolename =~ /^#{str}/}
	}
	oldCf = Readline.completion_case_fold = true

	until ! role.nil?
		rname = prompt( "Player role [#{roles.join(', ')}]" )
		role = MUES::Player::Role.const_get( rname.upcase.intern ) if
			roles.detect {|str| str.downcase == rname.downcase}
		if role.nil?
			puts ">>> Invalid role '#{rname}'."
		end
	end

	Readline.completion_case_fold = oldCf
	Readline.completion_proc = oldCp

	return role
end

main
