#
# MUES::CommandShell environment manipulation commands.
# $Id: environments.cmd,v 1.2 2002/09/12 12:53:28 deveiant Exp $
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

== Abstract

Create and/or load a environment object and make it available.

== Description
Creates a new environment of the specified class and associates it with the
specified name. If there is already an environment associated with the given
name, an error occurs.

== Code

  results = []

  if argString =~ %r{(\w+)\s+(?:as\s+)?(\w+)}
	klass = $1
	name = $2

	results <<
		MUES::OutputEvent::new( "Attempting to load the '#{klass}' environment as '#{name}'\n" ) <<
		MUES::LoadEnvironmentEvent::new( name, klass, context.user )

  else
    results << MUES::OutputEvent::new( self.usage )
  end

  return results



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

  unless argString =~ %r{(\w+)}
	  return MUES::OutputEvent::new( self.usage )
  end

  return [UnloadEnvironmentEvent.new( $1, context.user )]


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

  return [MUES::OutputEvent::new( output )]


### 'Connect' command
= connect

== Synonyms
play

== Abstract
Connect to the specified environment in the specified role.

== Usage
  connect [to] <environment> [as] <role>

== Code

  results = []
  if argString =~ %r{(?:\s*to\s*)?(\w+)\s+(?:as\s*)?(\w+)}
	  envName, roleName = $1, $2

	  ### Look for the requested role in the requested
	  ### environment, returning the new filter object if we find
	  ### it. Catch any problems as exceptions, and turn them into
	  ### error messages for output.
	  begin
		  env = MUES::ServerFunctions::getEnvironment( envName ) or
			  raise CommandError, "No such environment '#{envName}'."
		  role = env.getAvailableRoles( context.user ).find {|role|
			  role.name == roleName
		  }
		  raise CommandError, "Role '#{roleName}' is not currently available to you." unless
			  role.is_a?( MUES::Role )

		  results << OutputEvent.new( "Connecting..." )
		  results << env.getParticipantProxy( context.user, role )
		  results << OutputEvent.new( "connected.\n\n" )
	  rescue CommandError, SecurityViolation => e
		  results << OutputEvent.new( e.message )
	  end
  else
	  results << OutputEvent.new( usage() )
  end

  return results.flatten



### 'Disconnect' command
= disconnect

== Abstract
Disconnect from the specified role in the specified environment.

== Usage
  disconnect [<role> [in]] <environment>

== Code

  results = []
  roleName = nil
  envName = nil

  ### Parse the arguments, returning a usage message if we can't
  ### parse
  if argString =~ %r{(\w+)\s+(?:in\s*)?(\w+)}
	  roleName, envName = $1, $2
  elsif argString =~ %r{(\w+)}
	  envName = $1
  else
	  return [ MUES::OutputEvent.new( usage() ) ]
  end

  ### Look for a proxy from the specified environment
  begin
	  targetEnv = MUES::ServerFunctions::getEnvironment( envName ) or
		  raise CommandError, "No such environment '#{envName}'."
	  targetProxy = context.stream.findFiltersOfType( MUES::ParticipantProxy ).find {|f|
		  f.env == targetEnv && ( roleName.nil? || f.role.name == roleName )
	  } or raise CommandError, "Not connected to #{envName} #{roleName ? 'as ' + roleName : ''}"

	  results << OutputEvent.new( "Disconnecting from #{envName}..." )
	  targetEnv.removeParticipantProxy( targetProxy )
	  context.stream.removeFilters( targetProxy )
	  results << OutputEvent.new( " disconnected.\n\n" )
  rescue CommandError, SecurityViolation => e
	  results << OutputEvent.new( e.message )
  end

  return results.flatten


### 'Roles' command
= roles

== Abstract
List available roles in the specified environments.

== Usage
  roles [<environment names>]

== Code

  results = []
  envNames = []
  list = nil

  ### If they passed at least one environment name, parse them out
  ### of the line.
  if argString =~ %r{\w}
	  envNames = argString.scan(/\w+/)
  else
	  envNames = MUES::ServerFunctions::getEnvironmentNames
  end

  list = "\n"
  roleCount = 0
  envNames.each {|envName|

	  ### Look for the roles in the requested environment. Catch any
	  ### problems as exceptions, and turn them into error messages
	  ### for output.
	  begin
		  env = MUES::ServerFunctions::getEnvironment( envName ) or
			  raise CommandError, "No such environment '#{envName}'."
		  list << "%s (%s)\n" % [ envName, env.class.name ]
		  env.getAvailableRoles( context.user ).each {|role|
			  list << "    #{role.to_s}\n"
			  roleCount += 1
		  }
	  rescue CommandError, SecurityViolation => e
		  list << e.message + "\n"
	  end

	  list << "\n"
  }

  list << "(#{roleCount}) role/s currently available to you.\n\n"

  results << MUES::OutputEvent::new( list )
  return results.flatten



