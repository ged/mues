#
# The filters MUES::CommandShell command.
# $Id: filters.cmd,v 1.2 2002/09/12 12:54:27 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= filters

== Abstract
Display a user's IOEventStream filters.

== Description
This command displays a table of the filters in the specified user's
IOEventStream, or your own filters if you don't specify a username.

== Usage
  filters <username>
  filters

== Restriction
implementor

== Code

  # Code will be called like this:
  #   cmd.invoke( context, argString )
  # where 'context' is a MUES::Command::Context object, and argString is the
  # text of the command entered, with the command name and any leading/trailing
  # whitespace removed.
  if argString.strip.empty?
	  user = context.user
  elsif argString =~ /^\s*(\w+)\s*$/
	  username = $1.to_s
	  user = MUES::ServerFunctions::getUserByName( username ) 
	  if user.nil?
		  return [MUES::OutputEvent.new( "No such user '#{username}'" )]
	  end
  else
	  return [MUES::OutputEvent.new( self.usage )]
  end

  filterList = [ "Filters currently in #{user.username}'s stream:" ]
  user.ioEventStream.filters.sort.each {|filter|
	  filterList << filter.to_s
  }
  return [MUES::OutputEvent.new( filterList.join("\n\t") + "\n" )]


