#
# MUES::CommandShell environment manipulation commands.
# $Id: environments.cmd,v 1.1 2002/09/05 04:07:11 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

### Load environment
= loadenv

== Restriction

admin

== Usage

  loadenv <class> [as] <name>
  loadenv <name>

== Abstract

Create and/or load a environment object and make it available.

== Description

If specified with a class argument, creates a new environment of the specified
class and associates it with the specified name. If there is already an
environment associated with the given name, either in memory or in the Engine's
objectstore, this results in an error.

If specified with only a name, attempt to load the environment from the Engine's
objectstore. If no such environment exists in the objectstore, this results in
an error.

== Code

	if args =~ %r{(\w+)\s+(?:as\s+)?(\w+)}
		return OutputEvent.new( usage() )
	end

	return [ OutputEvent.new( "Attempting to load the '#{$1}' environment as '#{$2}'\n" ),
		LoadEnvironmentEvent.new( $2, $1, context.user ) ]


### Unload environment
= unloadenv

== Abstract

Shut down and unload a loaded environment object.

== Description

This command causes the server to unload a running environment after shutting it
down and disconnecting all participants.

== Usage

  unloadenv <environment name>

== Restriction

admin

== Code

  unless args =~ %r{(\w+)}
	  return OutputEvent.new( usage() )
  end

  return UnloadEnvironmentEvent.new( $1, context.user )


### List environments
= envlist

== Abstract
List known environment classes which may be loaded.

== Description
This command outputs a list of all available environment classes which may be
instantiated and run in the server.

== Restriction
admin

== Usage
  envlist

== Code
  output = "\nAvailable MUES Environment classes:\n\t"
  list = MUES::Environment.listEnvClasses
  if list.empty?
	  output << "(None)"
  else
	  output << list.join("\n\t")
  end
  output << "\n"

  return OutputEvent.new( output )
