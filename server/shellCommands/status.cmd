#
# MUES::CommandShell server-status command.
# $Id: status.cmd,v 1.2 2002/09/12 12:55:24 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

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
  return MUES::OutputEvent.new( MUES::ServerFunctions::engineStatusString )



