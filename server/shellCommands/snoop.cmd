# -*- default-generic -*-
#
# The snoop MUES::CommandShell command.
# Time-stamp: <30-Oct-2002 19:13:40 deveiant>
# $Id: snoop.cmd,v 1.1 2002/10/31 02:24:36 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= snoop

== Abstract

View (and control) another user's stream.

== Description

When this command is invoked, all of the specified user's IO will be visible to
you, prefixed with an '@' character and their login. In addition, you will be
able to enter commands into their stream by typing an '@' character followed by
their login and the command.

Unless the '-s' option is given (available to admin-level users only), the
snooped user will be apprised of your action.

== Usage

  snoop [OPTIONS] <user>

== Restriction

implementor

== Code

	silent = false

	options = argString.split(/\s+/)
	username = options.pop

	# Handle options
	options.each {|opt|
		case opt
		when '-s'
			raise CommandError, "Only admin users can snoop silently." unless
				context.user.isAdmin?
			silent = true
			
		else
			raise CommandError, "Unknown option '%s'" % opt
		end
	}
	
	# Fetch the corresponding user from the Engine
	user = MUES::ServerFunctions::getUserByName( username ) or
		raise CommandError, "No such user '#{username}'"
 	raise CommandError, "User is not logged in." unless user.activated?
 	raise CommandError, "You cannot snoop an admin" if
 		( ! context.user.isAdmin? && user.isAdmin? )

	snoopFilter = MUES::SnoopFilter::new( user, context.user, silent )
	msg = OutputEvent.new "Snooping %s.\n\n" % user.to_s

	return [ snoopFilter, msg ]


= unsnoop

== Abstract

Stop viewing another user's stream.

== Description

When this command is invoked, a previous snoop for the specified user is
cancelled. If no user is specified, all snoops currently in effect are
cancelled.

== Usage

  unsnoop [<user>]

== Restriction

implementor

== Code

	username = (argString =~ /(\S+)/) ? $1 : nil
	stream = context.user.ioEventStream

	targetFilters = stream.findFiltersOfType( MUES::SnoopFilter )
	if username
		targetFilters.reject! {|filt| filt.targetUser.username != username}
	end

	msg = ''
	stream.stopFilters( *targetFilters ) {|filt|
		msg << "Stopping snoop on '%s'\n" % filt.targetUser.username
	}
	msg << "\n"

	return [ MUES::OutputEvent::new(msg) ]

