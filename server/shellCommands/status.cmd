# -*- default-generic -*-
#
# MUES::CommandShell server-status command.
# Time-stamp: <14-Oct-2002 00:46:38 deveiant>
# $Id: status.cmd,v 1.4 2002/10/14 09:49:29 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

# Status command
= status

== Abstract
Check internal server status.

== Description
This command displays a server-status table, listing server version, uptime,
login sessions, and connected users.

== Usage
  status

== Restriction
creator

== Code
  return MUES::OutputEvent::new( MUES::ServerFunctions::engineStatusString )


# Scheduled events command
= scheduled

== Abstract
Display a table of scheduled events.

== Description
This command prints a table listing each event that is scheduled with the engine
for deferred execution.

== Restriction
implementor

== Code
  return MUES::OutputEvent::new( MUES::ServerFunctions::engineScheduledEventsString )


