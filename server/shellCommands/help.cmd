#
# The help MUES::CommandShell command.
# Time-stamp: <14-Sep-2002 08:02:18 deveiant>
# $Id: help.cmd,v 1.2 2002/09/15 07:44:37 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

### Help command
= help

== Abstract
Fetch help about a command or all commands.

== Description
If a command is specified, list detailed help on the given command.

If no command is given, list all available commands in a table with a brief
description and its synonyms.

== Usage
  help [<command>]

== Code

  helpTable = nil
  rows = []

  ### Fetch the help table from the shell's command table
  if argString =~ %r{(\w+)}
	helpHash = context.shell.commandTable.getHelpForCommand( $1 )

	# If there was no help available, just output a message to
	# that effect
	return OutputEvent.new( "No help found for '#{$1}'\n" ) if helpHash.nil?

	rows << "\n#{helpHash[:name]}\n#{'-' * helpHash[:name].length}\n\n" <<
		(helpHash[:description] || "#{helphash[:abstract]}\n\n") <<
		"Usage:\n"
	rows.push( *helpHash[:usage] )
	if context.user.isImplementor?
		rows << "Source: #{helpHash[:sourceFile]} line #{helpHash[:sourceLine]}\n"
	end
  else
	helpTable = context.shell.commandTable.getHelpTable()
	rows << "Help topics:\n"

	### Add a row or two for each table entry
	helpTable.sort.each {|cmd,desc|
		rows << "\t%20s : %s" % [ cmd, desc[0] ]
		rows << " [Synonyms: %s]" % desc[1].join(', ') unless desc[1].empty?
		rows << "\n"
	}
  end

  rows << "\n"
  return [ OutputEvent.new( rows ) ]


