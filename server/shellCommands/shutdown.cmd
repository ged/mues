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

  return [ OutputEvent.new( ">>> Shutting down the engine. <<<\n\n" ),
	   	   EngineShutdownEvent.new( context.user ) ]


