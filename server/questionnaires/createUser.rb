#!/usr/bin/ruby
#
#	The default questionnaire script used to create users.
#	$Id$
#

[
	# Username
	{
		:name		=> "username",
		:question   => "Username: ",
		:validator	=> lambda {|questionnaire,answer|
			questionnaire.abort() if answer.strip.empty?

			if answer.empty?
				questionnaire.abort
				return false

			elsif answer !~ /^[a-z]\w{2,}$/i
				questionnaire.error( "Username must begin with a-z " \
									 "character, and contain only " \
									 "alphanumerics.\n\n" )
				return false
			end

			if MUES::Engine.instance.started?
				if MUES::ServerFunctions::getUserNames.include?( answer.downcase )
					questionnaire.error( "User '#{answer}' already exists.\n\n" )
					return false
				end
			else
				questionnaire.message "Warning: Engine is not running, so user cannot be saved."
			end

			return true
		}, # lambda
	},

	# Available commands
	{
		:name		=> "availableCommands",
		:question	=> "Accessable commands: []: ",
		:validator	=> lambda {|questionnaire,answer|
			return true
		}, # lambda
	},

	# Real name
	{
		:name		=> "realname",
		:question	=> "Real name: ",
		:validator	=> /[a-z ]+/i,
		:errorMsg	=> "Invalid input. Real name must consist only of "\
						"letters and spaces.\n\n",
	},

	# Email address
	{
		:name		=> "emailAddress",
		:question	=> "Email address: ",

		# This is pretty simplistic, but we really only need to be
		# mostly correct. Perhaps replace this with something like
		# Perl's Email::Valid if it becomes an issue.
		:validator	=> /[a-z0-9][-\.!\w]+@[-\.\w]+\.[a-z]/i,
		:errorMsg	=> "Invalid input. Please confirm the address you " \
						"are typing is valid.\n\n",
	},

	# Password
	{
		:name		=> 'password',
		:hidden		=> true,
		:question	=> "Password: ",
		:validator	=> lambda {|questionnaire,answer|

			if answer.empty?
				questionnaire.abort

			elsif answer.length < 6
				questionnaire.error( "Invalid password: Must be at "\
									 "least 6 characters.\n\n" )
				return false

			elsif answer !~ /\W/
				questionnaire.error( "Invalid password: Must have at "\
									 "least one non-alphanumeric character.\n\n" )
				return false

			else
				return true
			end
		}, # lambda
	},

	# Password confirmation
	{
		:name		=> 'passwordConfirm',
		:hidden		=> true,
		:question	=> " (again): ",
		:validator	=> lambda {|questionnaire,answer|

			if answer != questionnaire.answers[:password]
				questionnaire.error( "Passwords didn't match.\n\n" )
				questionnaire.undoSteps( 1 )
				return false
			else
				return true
			end
		}, # lambda

	},

]

