# -*- default-generic -*-
#
# The reload MUES::CommandShell command.
# Time-stamp: <14-Oct-2002 03:03:28 deveiant>
# $Id: reload.cmd,v 1.1 2002/10/14 09:47:41 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= reload

== Abstract

Reload various parts of the system.

== Description

This command can be used to reload various parts of the system while it is
running.

'reload commands' will scan the directories which contain command files,
re-parsing the commands contained therein and replacing the current shell
commands with those that were reloaded.

'reload config' will cause the main server object to reload its configuration.

== Usage

  reload {commands,config}

== Restriction

implementor

== Code

  # Code will be called like this:
  #   cmd.invoke( context, argString )
  # where 'context' is a MUES::Command::Context object, and argString is the
  # text of the command entered, with the command name and any leading/trailing
  # whitespace removed.
  target = nil
  if argString =~ /(commands|config)/
    target = $1
  else
	raise CommandError, "No argument given.\n" + self.usage 
  end

  event = case target
		  when 'commands'
			  MUES::RebuildCommandRegistryEvent::new

		  when 'config'
			  raise CommandError, "Not implemented yet."

		  else
		      raise CommandError, "Unrecognized target '#{target}'"
		  end

  return [ OutputEvent.new( "Reloading #{target}\n\n" ), event ]


