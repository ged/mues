# -*- default-generic -*-
#
# The printobject MUES::CommandShell command.
#
#   Time-stamp: <17-Oct-2002 10:17:04 deveiant>
#   $Id: printobject.cmd,v 1.5 2002/10/23 02:17:45 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= printobject

== Abstract
Prettyprint an object.

== Description
This command outputs a pretty-printed representation of the object specified, or
the "current" context object if no id is specified.

== Usage

  printobject <id>
  printobject

== Restriction

implementor

== Synonyms

pp

== Code

  # Code will be called like this:
  #   cmd.invoke( context, argString )
  # where 'context' is a MUES::Command::Context object, and argString is the
  # text of the command entered, with the command name and any leading/trailing
  # whitespace removed.

  targetObject = nil
  prettyPrinted = ''

  # If an id was given, look it up in the global ObjectSpace
  if argString =~ /^\s*(\d+)\s*$/
    targetId = $1.to_i
    
	ObjectSpace.each_object( MUES::Object ) {|obj|
		next unless obj.id == targetId
		targetObject = obj
		break 
	}
	return OutputEvent.new( "No object found with id '#{targetId}'.\n\n" ) if
		targetObject.nil?

  # Otherwise use the context's "current object"
  else
    targetObject = context.evalContext
  end

  # Call the prettyprinter, using the arg-order of whichever version is loaded.
  if PP.instance_methods.include?( "guard_inspect_key" )
	PP.pp( targetObject, prettyPrinted, 79 )
  else
	PP.pp( targetObject, 79, prettyPrinted )
  end

  return [MUES::OutputEvent::new( prettyPrinted + "\n\n" )]


### Display an object in YAML format
= yamlobject

== Abstract
Display an object serialized into YAML.

== Description
This command outputs a YAML-formatted representation of the object specified, or
the "current" context object if no id is specified. YAML is a straightforward
machine parsable data serialization format designed for human readability.

The host machine must have YAML installed and loaded for this command to
work. If it does not, an error message will tell you so.

== Usage

  yamlobject <id>
  yamlobject

== Restriction

implementor

== Synonyms

yp

== Code

  # Code will be called like this:
  #   cmd.invoke( context, argString )
  # where 'context' is a MUES::Command::Context object, and argString is the
  # text of the command entered, with the command name and any leading/trailing
  # whitespace removed.

  # If YAML doesn't appear to be loaded, raise an error.
  raise CommandError, "YAML isn't loaded." unless ::Object::const_defined?( :YAML )

  targetObject = nil
  prettyPrinted = ''

  # If an id was given, look it up in the global ObjectSpace
  if argString =~ /^\s*(\d+)\s*$/
    targetId = $1.to_i
    
	targetObject = MUES::UtilityFunctions::getObjectByRubyId( targetId )
	return OutputEvent.new( "No object found with id '#{targetId}'.\n\n" ) if
		targetObject.nil?

  # Otherwise use the context's "current object"
  else
    targetObject = context.evalContext
  end

  # Call the prettyprinter, using the arg-order of whichever version is loaded.
  return [MUES::OutputEvent::new( targetObject.to_yaml + "\n\n" )]


