# -*- default-generic -*-
#
# The eval MUES::CommandShell command.
# Time-stamp: <27-Oct-2002 17:33:11 deveiant>
# $Id: eval.cmd,v 1.2 2002/10/29 07:37:41 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#


### 'Eval' command
= eval

== Restriction
admin

== Abstract
Evaluate the specified ruby code in the current object context.

== Description

This command evaluates the specified code in the context of the shell's current
context object and outputs the result.

== Usage
  eval <code>

== Code
  return [MUES::EvalCommandEvent::new( argString, context.evalContext, context.user )]



### 'Context' command
= context

== Restriction
admin

== Abstract
Set the object target of the /eval command to the object specified by the given id.

== Description

This command either displays the inspected form of the shell's context eval
target, if no id is specified, or looks up an object by Ruby id and sets the
shell context's target object to the resultant object if an id is given.

== Usage
  context [<id>]

== Code
  
  	msg = ''

	# If there weren't any arguments, just show the current context object
	if argString.empty?
		msg = "Current context object is:\n\n%s\n\n" %
			MUES::UtilityFunctions::trimString( context.evalContext.inspect, 60 )

	elsif argString =~ /^(\d+)$/
		id = $1.to_i

		obj = MUES::UtilityFunctions::getObjectByRubyId( id )
		context.evalContext = obj

		msg = "Set context object to:\n\n%s\n\n" % 
			MUES::UtilityFunctions::trimString( obj.inspect, 60 )

	else
		raise MUES::CommandError, self.usage
	end

	return [MUES::OutputEvent::new(msg)]



