#
# The shutdown MUES::CommandShell command.
# Time-stamp: <13-Oct-2002 22:13:13 deveiant>
# $Id: shutdown.cmd,v 1.3 2002/10/14 09:48:31 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= shutdown

== Restriction

admin

== Usage

  shutdown

== Abstract

Send a shutdown signal to the MUES Engine.

== Description

Send a shutdown signal to the MUES Engine, causing it to enter shutdown. All
connections will be closed, user objects and environments saved and destroyed,
and all subsystems will be told to shut down.

== Code

  # Hide the prompt
  context.shell.vars['prompt'] = ''

  return [ OutputEvent.new( ">>> Shutting down the engine. <<<\n\n" ),
	   	   EngineShutdownEvent.new( context.user ) ]


