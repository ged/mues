#
# MUES::CommandShell server-status command.
# $Id: status.cmd,v 1.1 2002/09/05 04:07:11 deveiant Exp $
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
  return MUES::OutputEvent.new( MUES::ServerFunctins::engine.statusString )



