#
# A collection of administrative commands for controlling the MUES::Engine:
# $Id: engine.cmd,v 1.1 2002/09/05 04:07:11 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= shutdown

== Abstract
Shut the server down safely.

== Description
Start the Engine's shutdown cycle. All connections will be closed, user objects
and environments will be saved and freed, all subsystems halted. After all this
is accomplished the server will exit.

== Usage
  shutdown

== Restriction
admin

== Code

  return [ OutputEvent.new( ">>> Shutting down the engine. <<<\n\n" ),
	  EngineShutdownEvent.new( context.user ) ]


