#
# The (>>>FILE_SANS<<<) MUES::CommandShell command.
# $Id: TEMPLATE.cmd.tpl,v 1.1 2002/09/05 04:07:11 deveiant Exp $
#
# == Authors:
# * (>>>USER_NAME<<<) <(>>>AUTHOR<<<)>
#

= (>>>FILE_SANS<<<)

== Abstract

(>>>POINT<<<)

== Description

(>>>MARK<<<)

== Usage

  (>>>FILE_SANS<<<)

== Restriction

(>>>restriction<<<)

== Synonyms



== Code

  # Code will be called like this:
  #   cmd.invoke( context, argString )
  # where 'context' is a MUES::Command::Context object, and argString is the
  # text of the command entered, with the command name and any leading/trailing
  # whitespace removed.
  return [ OutputEvent.new( "Running (>>>FILE_SANS<<<)\n\n" ) ]


>>>TEMPLATE-DEFINITION-SECTION<<<
("restriction" "Command Restriction: [admin,implementor,creator,user]" "" "" "user")
