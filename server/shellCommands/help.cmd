#
# The help MUES::CommandShell command.
# Time-stamp: <17-Oct-2002 09:52:06 deveiant>
# $Id: help.cmd,v 1.3 2002/10/23 02:17:09 deveiant Exp $
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

    # Find the maximum length of the commands
	length = helpTable.keys.inject(0) {|len,key|
		key.length > len ? key.length : len
	}

	# Add a row for each table entry
	helpTable.sort.each {|cmd,desc|
		row = "%#{length + 2}s : %s" % [ cmd, desc[0] ]
		row << " [Synonyms: %s]" % desc[1].join(', ') unless desc[1].empty?
		row << "\n"
		rows.push( row )
	}

	rows << "\nYou can get more detailed help about a command with /help <command>\n"
  end

  rows << "\n"
  return [ OutputEvent.new( rows ) ]


