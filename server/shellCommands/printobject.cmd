#
# The printobject MUES::CommandShell command.
# Time-stamp: <12-Oct-2002 10:48:03 deveiant>
# $Id: printobject.cmd,v 1.3 2002/10/13 23:26:21 deveiant Exp $
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


