#
# The initoff MUES::CommandShell command.
# Time-stamp: <13-Oct-2002 22:37:38 deveiant>
# $Id: initoff.cmd,v 1.1 2002/10/14 09:47:20 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= initoff

== Abstract

Turn server 'init mode' off.

== Description

This command turns the server's 'init mode' to off. There is no command to turn
init mode back on once it is turned off.

== Usage

  initoff

== Restriction

admin

== Code

  # Code will be called like this:
  #   cmd.invoke( context, argString )
  # where 'context' is a MUES::Command::Context object, and argString is the
  # text of the command entered, with the command name and any leading/trailing
  # whitespace removed.
  msg = ''

  if MUES::ServerFunctions::cancelInitMode
    msg = "Init mode is now off."
  else
    msg = "Init mode was already off."
  end
 
  return [ OutputEvent.new( msg + "\n\n" ) ]


