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
		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: commandshell.rb,v 1.3 2001/05/15 02:10:02 deveiant Exp $
		DefaultSortPosition = 700

		### Class attributes
		@@DefaultCommandString = '/'
		@@DefaultPrompt = 'mues> '

		### (PROTECTED) METHOD: initialize( aPlayer )
		### Initialize a new shell input filter for the specified player
		protected
		def initialize( aPlayer )
			super()
			@player = aPlayer
			@commandString = @@DefaultCommandString
			@prompt = @@DefaultPrompt

			@vars = {}
		end

		### Public methods
		public


		### METHOD: start( stream )
		### Start the filter 
		def start( stream )
			super( stream )
			queueOutputEvents( OutputEvent.new(@prompt) )
		end


		### METHOD: handleInputEvents( *events )
		### Handle input events by comparing them to the list of valid shell
		### commands and creating the appropriate events for any that do.
		def handleInputEvents( *events )
			unhandledInputEvents = []

			_debugMsg( 5, "Got #{events.size} input events to filter." )

			### :TODO: This is probably only good for a few commands. Eventually,
			### this will probably become a dispatch table which gets shell commands
			### dynamically from somewhere.
			events.flatten.each do |e|

				### If the input looks like a command for the shell, look for
				### commands we know about and take appropriate action when
				### one is found
				if e.data =~ /^#{@commandString}(.*)/
					command = $1
					output = []

					case command
					when /^q(uit)?/
						engine.dispatchEvents( PlayerLogoutEvent.new(@player) )
						break

					when /^shutdown/
						engine.dispatchEvents( EngineShutdownEvent.new(@player) )
						break

					when /^status/
						output << OutputEvent.new(engine.statusString)

					when /^debug\b\s*(.*)/
						arg = $1

						if arg =~ /=\s*(\d)/
							level = $1
							output << OutputEvent.new( "Setting shell debug level to #{level}.\n" )
							self.debugLevel = level

						else
							output << OutputEvent.new( "Shell debug level is currently #{self.debugLevel}.\n" )
						end

					when /^threads/
						thrList = Thread.list.collect {|t|
							"\t[%10s] prio: %02d  stat: %5s  sl: %1d  aoe: %1s" % [
								t.id,
								t.priority,
								t.status,
								t.safe_level,
								t.abort_on_exception ? "t" : "f"
							]
						}
						thrTable = "#{thrList.length} threads: \n" + thrList.join("\n") + "\n\n"
						output << OutputEvent.new(thrTable)

					when /^set\b\s*(.*)/
						stuffToSet = $1

						if stuffToSet =~ /=/
							# Split into key = value pair
							key, val = stuffToSet.split( /\s*=\s*/, 2 )
							key = key.strip.downcase

							# Strip enclosing quotes from the value
							_debugMsg 4, "Stripping quotes."
							val.gsub!( /\s*(["'])((?:[^\1]+|\\.)*)\1/ ) {|str| $2 }
							_debugMsg 4, "Done stripping."

							# Take special action for variables we know about
							case key
							when /^prompt$/i
								@prompt = val
							else
								_debugMsg 4, "Setting variable #{key}"
								output << OutputEvent.new("(Created variable '#{key}') ") unless @vars.has_key?( key )
								@vars[ key ] = val
							end
							output << OutputEvent.new("Setting #{key} = '#{val}'\n")

						elsif stuffToSet =~ /(\w+)/
							key = $1
							if @vars.has_key? key
								output << OutputEvent.new("#{key} = '@vars[key]'\n")
							else
								output << OutputEvent.new("#{key} = nil\n")
							end
							
						else
							varlist = ''
							if @vars.empty?
								varlist = "(No variables set)\n"
							else
								varlist = "Variables:\n"
								@vars.each {|key,val| varlist << "\t%20s = '%s'\n" % [ key, val ] }
							end

							output << OutputEvent.new(varlist)
						end

					when /(.*)/
						output << OutputEvent.new("No such command '#{$1}'\n")
					end

					queueOutputEvents( *output )

				### If the input doesn't look like a command for the shell, add
				### it to the list of input that we'll pass along to the next
				### filter.
				else
					unhandledInputEvents << e
				end

				### No matter what the input, we're responsible for the prompt,
				### so send it for each input event.
				queueOutputEvents( OutputEvent.new(@prompt) )
			end

			return unhandledInputEvents
		end

	end # class CommandShell
end # module MUES

