#!/usr/bin/ruby
#
#	The default password-changing questionnaire
#	$Id$
#

[
	# Previous password
	{
		:name		=> 'oldPassword',
		:hidden		=> true,
		:question   => "Old password: ",
		:validator	=> Proc::new {|qnaire, answer|
			user = qnaire.data[:user]

			if answer.empty?
				if user.cryptedPass == '*'
					return true
				else
					qnaire.abort
				end
			elsif user.passwordMatches?(answer)
				return true
			else
				qnaire.error("Old password does not match.\n\n")
				return false
			end
		} # lambda
	},

	# Password
	{
		:name		=> 'newPassword',
		:hidden		=> true,
		:question	=> "New password: ",
		:validator	=> lambda {|qnaire, answer|
			if answer.empty?
				qnaire.abort

			elsif answer.length < 6
				qnaire.error( "Invalid password: Must be at "\
									 "least 6 characters.\n\n" )
				return false

			elsif answer !~ /\W/
				qnaire.error( "Invalid password: Must have at "\
									 "least one non-alphanumeric character.\n\n" )
				return false

			else
				return true
			end
		} # lambda
	},

	# Password confirmation
	{
		:name		=> 'passwordConfirm',
		:hidden		=> true,
		:question	=> "     (again): ",
		:validator	=> lambda {|questionnaire,answer|

			if answer != questionnaire.answers[:newPassword]
				questionnaire.error( "Passwords didn't match.\n\n" )
				questionnaire.undoSteps( 1 )
				return false
			else
				return true
			end
		}, # lambda
	}
]

