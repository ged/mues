#!/usr/bin/ruby -w

require "readline"
require "mues/User"
require "mues/ObjectStore"

include Readline

def main
	unless ARGV.length.nonzero? && ARGV[0] =~ /^\w{3,}$/
		$stderr.puts "usage: #{$0} <username> [<driver>]"
		exit 1
	end

	user = ARGV.shift
	driver = ARGV.shift || "Mysql"

	puts "Creating user record for '#{user}' in a #{driver} objectstore."
	os = MUES::ObjectStore.new( driver, 'mues', 'localhost', 'deveiant', '3l3g4nt' )
	user = os.createUser( user )

	user.password = prompt( "Password" )
	user.realname = prompt( "Real name" )
	user.emailAddress = prompt( "Email" )

	user.role = promptForRole()

	print "Storing new user record:"
	os.storeUser( user )
	puts "done."

	puts user.inspect
end

def prompt( promptString )
	promptString.chomp!
	return readline( "#{promptString}: " ).strip
end

def promptForRole
	role = nil
	roles = MUES::User::Role.constants.collect {|s| s.downcase}
	oldCp = Readline.completion_proc = Proc.new {|str|
		roles.find_all {|rolename| rolename =~ /^#{str}/}
	}
	oldCf = Readline.completion_case_fold = true

	until ! role.nil?
		rname = prompt( "User role [#{roles.join(', ')}]" )
		role = MUES::User::Role.const_get( rname.upcase.intern ) if
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
