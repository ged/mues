#
# The 'threads' MUES::CommandShell command.
# $Id: threads.cmd,v 1.1 2002/09/05 04:07:11 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= threads

== Abstract
Display server threads table.

== Description
This command displays a table of the currently-running threads, along with the
id, priority, state, $SAFE-level, abort_on_exception status, and description of
each one.

== Usage
  threads

== Restriction
implementor

== Code

  thrList = "#{Thread.list.length} running threads:\n\n" <<
	  "\t%11s  %-4s  %-5s  %-5s  %-5s %-20s\n" % %w{Id Prio State Safe Abort Description}

  Thread.list.each {|t|
	  thrList << "\t%11s  %-4d  %-5s  %-4d   %-5s %-20s\n" % [
		  t.id,
		  t.priority,
		  t.status,
		  t.safe_level,
		  t.abort_on_exception ? "t" : "f",
		  t.desc
	  ]
  }
  thrList << "\n"
  return [ MUES::OutputEvent.new(thrList) ]


