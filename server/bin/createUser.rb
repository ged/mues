#!/usr/bin/ruby -w

if $0 =~ /server#{File::Separator}bin#{File::Separator}/
	baseDir = $0.gsub( /server#{File::Separator}bin#{File::Separator}.*/, '' )
	baseDir = '.' if baseDir.empty?
	$: << File.join( baseDir, "lib" )
	DefaultConfigFile = File.join( baseDir, "MUES.cfg" )
else
	DefaultConfigFile = "MUES.cfg"
end

require "readline"
require "mues/User"
require "mues/Config"
require "mues/ObjectStore"

include Readline

class UserTool

	def createUser( username, configFile )
		config = MUES::Config.new( configFile )

		puts "Creating user record for '#{username}' in a #{config['ObjectStore']['Driver']} objectstore."
		os = MUES::ObjectStore.new( config )
		os.createUser( username ) {|user|

	user.password = prompt( "Password" )
	user.realname = prompt( "Real name" )
	user.emailAddress = prompt( "Email" )

			user.accounttype = promptForType()

			puts user.inspect
			print "\nStoring new user record:"
		}
	puts "done."

	end

	def prompt( promptString )
	promptString.chomp!
	return readline( "#{promptString}: " ).strip
	end

	def promptForType
		type = nil
		types = MUES::User::AccountType.constants.collect {|s| s.downcase}.reject {|s| s =~ /name/}
	oldCp = Readline.completion_proc = Proc.new {|str|
			types.find_all {|typename| typename =~ /^#{str}/}
	}
	oldCf = Readline.completion_case_fold = true

		until ! type.nil?
			rname = prompt( "User type [#{types.join(', ')}]" )
			type = MUES::User::AccountType.const_get( rname.upcase.intern ) if
				types.detect {|str| str.downcase == rname.downcase}
			if type.nil?
				puts ">>> Invalid type '#{rname}'."
		end
	end

	Readline.completion_case_fold = oldCf
	Readline.completion_proc = oldCp

		return type
	end
end

if $0 == __FILE__
	unless ARGV.length.nonzero? && ARGV[0] =~ /^\w{3,}$/
		$stderr.puts "usage: #{$0} <username> [<configFile>]"
		exit 1
	end

	username = ARGV.shift
	configFile = ARGV.shift || "MUES.cfg"

	u = UserTool.new
	u.createUser( username, configFile )

end
