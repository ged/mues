# -*- default-generic -*-
# User-related MUES::CommandShell commands.
# Time-stamp: <05-Oct-2002 23:30:16 deveiant>
# $Id: users.cmd,v 1.1 2002/10/06 07:42:53 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#


### 'users' command
= users

== Abstract

Display user records.

== Description

This command lists user accounts in a MUES server whose name matches a given
pattern (a regular expression), or, if no pattern is specified, all user
accounts.

== Usage

  users [<pattern>]

== Restriction

implementor

== Code

	re = nil

	# If they specified a pattern, strip leading '/' characters, if present, and
	# compile a Regexp from the rest. If the regex doesn't compile, just send
	# output describing why.
	if argString =~ /\S/
		argString.strip!
		argString.gsub!( %r{^/|/$}, '' )
		begin
			re = Regexp::new( argString )
		rescue RegexpError => e
			return [ MUES::OutputEvent::new("Malformed pattern: #{e.message}") ]
		end

	# If they didn't supply a pattern, just use on that'll match anything valid
	# username.
	else
		re = /\w/
	end

	usernames = MUES::ServerFunctions::getUserNames()
	matchedNames = usernames.grep( re )

	output = "User Accounts\n\n    " <<
		matchedNames.join("\n    ") <<
		"\n  Displayed #{matchedNames.length} of #{usernames.length} user(s)\n\n"

	return [ MUES::OutputEvent::new(output) ]



### Add a new user
= adduser

== Synonyms

useradd

== Restriction

admin

== Abstract

Create a new user account.

== Description

This command allows an admin to create a new user account for the server.

== Usage

  adduser

== Code

  # The MUES::User class has a factory method for creating Questionnaire objects
  # for building instances of itself, so just use that.
  return [ MUES::User::getCreationQuestionnaire ]


