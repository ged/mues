#
# The gc MUES::CommandShell command.
# Time-stamp: <14-Sep-2002 08:02:06 deveiant>
# $Id: gc.cmd,v 1.2 2002/09/15 07:44:37 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= gc

== Restriction

admin

== Usage

  gc

== Abstract

Start Ruby's garbage-collector.

== Description

Start the Ruby garbage collector manually, possibly reclaiming the memory
occupied by objects which have gone out of scope. Note that this is never
necessary for the purposes of memory management -- Ruby does this by itself
without any intervention -- but it can sometimes help in tracking down bugs to
be able to start the GC explicitly.

== Code

  return [ OutputEvent.new( "Starting garbage collection.\n\n" ),
	  	   GarbageCollectionEvent.new ]

