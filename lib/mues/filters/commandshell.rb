#!/usr/bin/ruby
###########################################################################
=begin

=CommandShell.rb

== Name

CommandShell - a MUES command shell input filter class

== Synopsis

  require "mues/filters/CommandShell"

== Description

This is a command shell input filter class. It provides a simple shell for
interacting with the MUES Engine after logging in.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

module MUES
	class CommandShell < IOEventFilter

		### Class constants
		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: commandshell.rb,v 1.1 2001/03/29 02:34:27 deveiant Exp $

		### Class attributes
		@@DefaultSortPosition = 700
		@@DefaultCommandString = '/'

		### (PROTECTED) METHOD: initialize( aPlayer )
		### Initialize a new shell input filter for the specified player
		protected
		def initialize( aPlayer )
			super()
			@player = aPlayer
			@commandString = @@DefaultCommandString
		end

		### Public methods
		public

		### METHOD: handleInputEvents( *events )
		### Handle input events by comparing them to the list of valid shell
		### commands and creating the appropriate events for any that do.
		def handleInputEvents( *events )
			unknownCommands = []

			_debugMsg( 1, "Got #{events.size} input events to filter." )

			### :TODO: This is probably only good for a few commands. Eventually,
			### this will probably become a dispatch table which gets shell commands
			### dynamically from somewhere.
			events.flatten.each do |e|

				case e.data
				when /^#{@commandString}q(uit)?/
					engine.dispatchEvents( PlayerLogoutEvent.new(@player) )
					break

				when /^#{@commandString}shutdown/
					engine.dispatchEvents( EngineShutdownEvent.new(@player) )
					break

				when /^#{@commandString}status/
					queueOutputEvents( OutputEvent.new(engine.statusString) )

				else
					unknownCommands.push e
				end

				queueOutputEvents( OutputEvent.new(@player.prompt) )
			end

			return unknownCommands
		end

	end # class CommandShell
end # module MUES

