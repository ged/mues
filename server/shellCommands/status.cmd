#
# MUES::CommandShell server-status command.
# Time-stamp: <14-Sep-2002 08:03:32 deveiant>
# $Id: status.cmd,v 1.3 2002/09/15 07:44:37 deveiant Exp $
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



