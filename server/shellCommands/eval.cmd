# -*- default-generic -*-
#
# The eval MUES::CommandShell command.
# Time-stamp: <22-Oct-2002 22:01:00 deveiant>
# $Id: eval.cmd,v 1.1 2002/10/23 05:00:28 deveiant Exp $
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




