# -*- default-generic -*-
# User-related MUES::CommandShell commands.
# Time-stamp: <24-Oct-2002 16:33:39 deveiant>
# $Id: users.cmd,v 1.8 2002/10/25 05:09:17 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
# * Martin Chase <stillflame@FaerieMUD.org>
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


### Show a user's information
= showuser

== Synonyms
finger

== Abstract
Show a user record.

== Description

This command allows a user to view her own user record, or the record of another
user if the invoking user has implementor privileges.

== Usage

  showuser [<username>]

== Code

  # Get the target user, either from the command arguments, or from the
  # current context.
  user = nil
  if argString =~ /(\S+)/
	username = $1
	if username == context.user.login
		user = context.user
	elsif ! context.user.isImplementor?
		raise CommandError, "You cannot view other users' information."
	else
		user = MUES::ServerFunctions::getUserByName( username ) or
			raise CommandError, "No such user '#{username}'"
	end
  else
    user = context.user
  end

  # Build a detailed user record display
  output = []
  output << "User record for user '%s':\n" % user.realname
  output << "\tAccount type: %s\n" % MUES::User::AccountType::Name[user.accountType]
  output << "\tCreated: #{user.timeCreated.to_s}\n" 

  if context.user.isAdmin?
    output << "\tCrypted password: #{user.cryptedPass}\n"
  end

  output << "\tReal name: #{user.realname}\n"
  output << "\tEmail address: #{user.emailAddress}\n"
  output << "\tLast login: #{user.lastLoginDate.to_s}\n"
  output << "\tLast host: #{user.lastHost}\n"

  if context.user.isImplementor?
    output << "\tFirst login tick: #{user.firstLoginTick}\n"
  end

  output << "\tPreferences: \n" + user.preferences.collect {|k,v| "\t\t#{k} => #{v}\n"}.to_s +
		"\n\n"

  return [ MUES::OutputEvent::new(output.join('')) ]


### Change a user's password
= password

== Abstract
Change the password of a user.

== Description
Allows a user to change their account password, or the password of another user
if the invoking user has admin privileges.

== Usage

  password [<username>]

== Synonyms
passwd

== Code

	user = nil
	if argString =~ /(\S+)/
		username = $1
		if username == context.user.login
			user = context.user
		elsif ! context.user.isAdmin?
			raise CommandError, "You cannot alter other users' passwords."
		else
			user = MUES::ServerFunctions::getUserByName( username ) or
				raise CommandError, "No such user '#{username}'"
			raise CommandError, "You cannot alter another admin's password." if
				user.isAdmin?
		end
	else
		user = context.user
	end

	# The MUES::User class has a factory method for creating Questionnaire objects
	# for changing a user's password.
	return [MUES::User::getPasswordQuestionnaire(user, (context.user != user))]


### Change a user's attributes
= setuser

== Abstract
Change an attribute of a user.

== Synonyms
moduser
usermod

== Description
Allows a user to change their account information, or the account information of
another user if the invoking user has admin priviledges.

== Usage

	setuser <attribute> [<username>]

== Code

	modableAttr = %w[realname emailAddress]
	adminModableAttr = modableAttr + %w[username]
	user = nil

	# attribute + user
	if argString =~ /(\S+)\s+(\S+)/
		attribute = $1
		username = $2
		if username == context.user.login
			user = context.user
		elsif ! context.user.isAdmin?
			raise CommandError, "You cannot alter other users' accounts."
		else
			user = MUES::ServerFunctions::getUserByName( username ) or
				raise CommandError, "No such user '#{username}'"
		end

	# attribute only
	elsif argString =~ /(\S+)/
		user = context.user
		attribute = $1

	else
		raise CommandError, self.usage
	end

	# Match the attribute to change against the list of modifiable ones.
	if context.user.isAdmin?
		attributes = adminModableAttr.find_all {|attr| attr.match(attribute)}
	else
		attributes = modableAttr.find_all {|attr| attr.match(attribute)}
	end

	# Handle attribute not found
	if attributes.nil? or attributes.empty?
		raise CommandError, "Invalid attribute '%s'.  Must be one of: %s" % [
			attribute, (context.user.isAdmin? ?
				adminModableAttr :
				modableAttr).join(", ") 
		]

	# Handle ambiguous attribute
	elsif attributes.length > 1
		raise CommandError, "Ambiguous attribute: %s" % attributes.join(" ")
	end
	
	# The MUES::User class has a factory method for creating Questionnaire
	# objeccts for changing a user's attributes.
	return [MUES::User::getAttributeQuestionnaire(user, attributes[0])]


### Delete a user
= deluser

== Abstract
Remove a registered user.

== Synonyms
rmuser

== Description
Allows an admin to remove a user account entirely. You can prevent the user from
logging in without removing their user record by using the ban system.

== Usage
	deluser <username>

== Code

	# attribute only
	unless argString =~ /(\S+)/
		raise CommandError, self.usage
	end

	username = $1
	user = MUES::ServerFunctions::getUserByName( username ) or
		raise CommandError, "No such user '#{username}'"
	raise CommandError, "User is currently logged in." if user.activated?

	prompt = "Remove %s: Are you sure?" % user.to_s
	confirm = MUES::Questionnaire::Confirmation( prompt ) {|qnaire|
		if qnaire.confirmed?
			MUES::ServerFunctions::unregisterUser( user )
			qnaire.message "Done.\n\n"
		end
	}

	return [confirm]

