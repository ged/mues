#!/usr/bin/ruby
#
# This file is a collection of classes which are used in the MUES command
# shell. The command shell is a command interface for user interaction with the
# MUES::Engine. This file contains the following classes:
#
# [MUES::CommandShell]
#   The main command shell class; it is a derivative of MUES::InputFilter.
#
# [MUES::CommandShell::Command]
#	The Flyweight class for all shell commands.
#
# [MUES::CommandShell::Context]
#	A shell context class that is used by the shell to maintain command
#	invocation context.
#
# [MUES::CommandShell::CommandTable]
#	A command table for looking up command objects by name, synonym, or
#	abbreviation.
#
# [MUES::CommandShell::Factory]
#   An Abstract Factory object class that loads and maintains a registry of
#   MUES::CommandShell::Command objects and creates MUES::CommandShell objects
#   for MUES::User objects according to parameters specified at creation.
#
# [MUES::CommandShell::CommandParser]
#   A parser class for parsing command specifications.
#
# == Synopsis
#
#  require 'mues/filters/commandshell'
#
#  cfactory = MUES::CommandShell::Factory::new( 'server/shellCommands' )
#
# == To Do
# 
# * Perhaps add soundex matching if there are no abbrev matches for a command?
#
# == Rcsid
# 
# $Id: commandshell.rb,v 1.35 2003/10/13 05:16:43 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "sync"
require "singleton"
require "find"
require "observer"
#require "Soundex"

require 'mues/object'
require 'mues/mixins'
require 'mues/events'
require 'mues/exceptions'
require 'mues/user'
require 'mues/filters/inputfilter'

module MUES

	### This class is a MUES::InputFilter that provides connected users with the
	### ability to execute commands in the context of their MUES::User object.
	class CommandShell < InputFilter ; implements MUES::Debuggable

		include MUES::ServerFunctions, MUES::Factory

		### Class constants
		Version = /([\d\.]+)/.match( %q{$Revision: 1.35 $} )[1]
		Rcsid = %q$Id: commandshell.rb,v 1.35 2003/10/13 05:16:43 deveiant Exp $
		DefaultSortPosition = 990

		### Class globals

		# The default characters that designate an input line as a command
		DefaultCommandPrefix	= '/'

		# The default prompt to display when the command shell is forward
		DefaultPrompt			= 'mues> '


		### Return a new shell input filter for the specified user (a MUES::User
		### object) with the given <tt>commandTable</tt> (an instance of
		### MUES::CommandShell::CommandTable or derivative), and the given
		### <tt>parameters</tt>.
		def initialize( user, commandTable, parameters={} )
			checkType( user, MUES::User )
			checkType( commandTable, MUES::CommandShell::CommandTable )
			checkResponse( parameters, :[] )

			super()

			@user				= user
			@commandTable		= commandTable
			@commandTableMutex	= Sync::new

			@commandPrefix		= parameters["command-prefix"]
			@vars				= {}

			if user.preferences.has_key?( 'prompt' )
				@vars['prompt'] = user.preferences['prompt']
			else
				@vars['prompt'] = parameters["default-prompt"]
			end

			# When the CommandShell::Factory updates its command registry, this
			# flag is set to the factory instance in all shells created from
			# it. On the next input event, the shell should ask the factory for
			# a new table via #createCommandTableForUser().
			@needNewTable		= false

			# These are passed as arguments to #activate
			@stream				= nil
			@context			= nil

			self.log.info( "Initialized command shell for %s. Prefix = '%s'" % [ user.to_s, @commandPrefix ] )
		end


		######
		public
		######

		# The Hash of shell variables currently set in the shell
		attr_accessor	:vars

		# The prefix string which will be used to recognize shell commands
		attr_accessor	:commandPrefix

		# The user (MUES::User) object that owns this shell
		attr_reader		:user

		# The command table of commands available in this shell (a
		# MUES::CommandShell::CommandTable object).
		attr_reader		:commandTable


		### Start the filter on the specified stream (a MUES::IOEventStream
		### object).
		def start( stream )
			results = super( stream )
			@stream = stream
			@context = Context::new( self, @user, stream, nil )
			queueOutputEvents( OutputEvent.new(@vars['prompt']) )
			debugMsg( 2, "Starting command shell for #{@user.to_s}" )

			return results
		end


		### Stop the filter for the specified stream (a MUES::IOEventStream
		### object).
		def stop( stream )
			@stream = nil
			@context = nil
			debugMsg( 2, "Stopping command shell for #{@user.to_s}" )

			super( stream )
		end


		### Notify the shell that its command table is out of date, and should
		### be replaced with the specified one.
		def update( factory )
			@needNewTable = factory
		end


		### Handle the specified input events by comparing them to the list of
		### valid shell commands and creating the appropriate events for any
		### that match.
		def handleInputEvents( *events )
			unhandledInputEvents = []

			debugMsg( 5, "Got #{events.size} input events to filter." )

			# If the factory has notified the shell of an updated command
			# registry, reload the table
			self.reloadCommandTable( @needNewTable ) if @needNewTable

			# Extract commands from each event, run them if they match a
			# command we know about, and then dispatch the resultant events.
			events.flatten.each do |e|

				# If the input looks like a command for the shell, look for
				# commands we know about and take appropriate action when
				# one is found
				if e.data =~ /^#{@commandPrefix}(\w+)\b(.*)/
					command = $1
					argString = $2.strip

					debugMsg( 4, "Got command '#{command}' with args: '#{argString}'" )
					results = []

					# Look up the command in the command table, trying to get
					# the specific one first
					@commandTableMutex.synchronize( Sync::SH ) {
						if (( commandObj = @commandTable[command] ))
							debugMsg( 4, "Found command '%s'." % commandObj.to_s )
							results << commandObj.invoke( @context, argString )
						elsif ( ! (objects = @commandTable.approxSearch(command)).empty? )
							debugMsg( 4, "Ambiguous command." )
							results << OutputEvent.new( "Ambiguous command '#{command}': Matches [",
													   objects.collect {|o| o.name}.join(', '), "]\n" )
						else
							debugMsg( 2, "Command '#{command}' not found." )
							results << OutputEvent.new( "No such command '#{command}'.\n" )
						end
					}
					results.flatten!

					# Separate out all the different kinds of events for
					# proper dispatch
					output = results.find_all {|e| e.kind_of?( MUES::OutputEvent )}
					results -= output
					input = results.find_all {|e| e.kind_of?( MUES::InputEvent )}
					results -= input
					newFilters = results.find_all {|e| e.kind_of?( MUES::IOEventFilter )}
					results -= newFilters

					# Add any new filters to our parent event stream
					@stream.addFilters( *newFilters ) unless newFilters.empty?

					# Dispatch events
					unhandledInputEvents << input unless input.empty?
					queueOutputEvents( *output ) unless output.empty?
					dispatchEvents( *results ) unless results.empty?

				# If the input doesn't look like a command for the shell, add
				# it to the list of input that we'll pass along to the next
				# filter.
				else
					debugMsg( 4, "'#{e.data}' Doesn't look like a commandshell command. Skipping." )
					unhandledInputEvents << e
				end

				# No matter what the input, we're responsible for the prompt,
				# so send it for each input event.
				queueOutputEvents( PromptEvent::new(self.vars['prompt']) )
			end

			return unhandledInputEvents
		end


		#########
		protected
		#########

		### Reload the shell's command table from the specified factory (a
		### MUES::CommandShell::Factory).
		def reloadCommandTable( factory )
			@commandTableMutex.synchronize( Sync::EX ) {
				oldTable = @commandTable
				begin
					@commandTable = factory.createCommandTableForUser( @user )
				rescue => e
					self.log.error "Error while loading updated command table: #{e.message}"
					@commandTable = oldTable
				ensure
					@needNewTable = false
				end
			}
		end



		#############################################################
		###	A S S O C I A T E D   O B J E C T   C L A S S E S
		#############################################################

		### The shell command object class. Commands objects are wrappers around
		### event-generating functions triggered by user input. They are loaded by
		### a MUES::CommandShell::Factory via a MUES::CommandShell::CommandParser,
		### and references to the ones which are executable by a particular
		### MUES::User are given to her MUES::CommandShell at creation. The
		### registry of commands is kept up to date by occasionally checking for
		### updated files.
		class Command < MUES::PolymorphicObject ; implements MUES::Debuggable

			include MUES::User::AccountType, MUES::TypeCheckFunctions

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.35 $} )[1]
			Rcsid = %q$Id: commandshell.rb,v 1.35 2003/10/13 05:16:43 deveiant Exp $


			### Instantiate and return a new Command object with the specified
			### values. The arguments are as follows:
			###
			### [<tt>name</tt>]
			###   The name of the command; the text which invokes it in the
			###   shell. Must be unique across all commands.
			### [<tt>sourceFile</tt>]
			###   The file from which this command was loaded.
			### [<tt>sourceLine</tt>]
			###   The line number of the <tt>sourceFile</tt> line which contains
			###   the start of this command.
			### [<tt>commandSpec</tt>]
			###   A hash of meta-information about the command, which should
			###   contain the following keys (Symbols):
			###
			###   [<tt>:abstract</tt>]
			###     A one-line description of the command, which will be used to
			###     describe it in lists and short help. It should be no longer
			###     than 70 characters.
			###   [<tt>:description</tt>]
			###     A long description of the command which will be used in
			###     detailed help screens. The text can be as long as is needed;
			###     lines which are not indented will be automatically wrapped
			###     to the width of the user's screen. Indented lines will be
			###     displayed as-is, and should therefore not be longer than 70
			###     characters.
			###   [<tt>:usage</tt>]
			###     A (potentially) multi-line usage text string, which is
			###     displayed to the user when an invocation error is raised. It
			###     should provide templates for use for each possible
			###     invocation of the command. Each line should be no longer
			###     than 70 characters.
			###   [<tt>:restriction</tt>]
			###     An Integer or String describing the lowest user account type
			###     that should be able to invoke this command. The value may be
			###     any one of the values in MUES::User::AccountType, or a
			###     case-insensitive string version of any of the types (eg.,
			###     AccountType::ADMIN can be specified as 'admin' or 'Admin' or
			###     'ADMIN').
			###   [<tt>:synonyms</tt>]
			###     An Array of zero or more names which should be considered
			###     exactly equivalent to the primary name for the purposes of
			###     invocation.
			### 
			### [<tt>body</tt>]
			###   The body of the 'invoke' method, passed either as a parameter
			###   or as an inline block (ie., a Proc or Method object). The body
			###   will be invoked like this:
			###     body.call( context, argString)
			###   where <tt>context</tt> is a MUES::CommandShell::Context
			###   object, and <tt>argString</tt> is the text of the command
			###   entered, with the command name and any leading/trailing
			###   whitespace removed.
			def initialize( name, sourceFile, sourceLine, commandSpec, body )
				checkType( name, ::String )
				checkType( sourceFile, ::String )
				checkType( sourceLine, ::Integer )
				checkType( commandSpec, ::Hash )
				checkType( body, ::String )

				checkType( commandSpec[:abstract], ::String )
				checkType( commandSpec[:description], ::String, ::NilClass )
				checkType( commandSpec[:usage], ::String, ::NilClass )
				checkType( commandSpec[:restriction], ::String, ::Integer )
				checkType( commandSpec[:synonyms], ::Array )

				debugMsg( 3, "Creating a new command '#{name}' from '#{sourceFile}':#{sourceLine}" )

				@name			= name
				@sourceFile		= sourceFile
				@sourceLine		= sourceLine

				@abstract		= commandSpec[:abstract]
				@description	= commandSpec[:description] || @abstract
				@usage			= commandSpec[:usage] || @name
				@synonyms		= commandSpec[:synonyms]

				# Normalize the restriction argument, set it, and make sure it's
				# valid.
				case commandSpec[:restriction]
				when String
					val = MUES::User::AccountType::Map[ commandSpec[:restriction].downcase ] or
						raise ArgumentError,
						"No such account type '#{commandSpec[:restriction]}'"
					@restriction = val

				when Integer
					val = commandSpec[:restriction].abs
					raise ArgumentError, "Restriction value out of bounds: %d > %d" % 
						[ val, MUES::User::AccountType::Map.values.max ] unless
						val <= MUES::User::AccountType::Map.values.max 
					@restriction = val

				else
					raise ArgumentError,
						"Illegal restriction spec: '#{commandSpec[:restriction].inspect}'"
				end

				# Create the invocation method for this instance
				createInvokeMethod( body, sourceFile, sourceLine )

				super()
			end


			######
			public
			######

			# The name by which the command is invoked
			attr_reader	:name

			# The source file which contains this command
			attr_reader :sourceFile

			# The line number of the command declaration for this command
			attr_reader :sourceLine

			# The one-line short description of the command.
			attr_reader :abstract

			# The description of the command.
			attr_reader	:description

			# The usage messages
			attr_reader :usage

			# The restriction level of the command (one of
			# MUES::User::AccountType).
			attr_reader :restriction

			# A (potentially empty) Array of synonyms for the command.
			attr_reader	:synonyms


			### Handle execution of command objects which haven't had their
			### <tt>invoke</tt> methods defined.
			def method_missing( method, *args )
				super( method, *args ) unless method == :invoke
				def self.invoke( context, argString )
					self.log.error( "No invoke method for #{@name} (#{sourceFile}:#{sourceLine})" )
					return [ MUES::OutputEvent::new("Command disabled -- no invocation defined.") ]
				end

				self.invoke( *args )
			end


			### Returns true if the command can be used by the user specified (a
			### MUES::User object).
			def canBeUsedBy?( user )
				checkType( user, MUES::User )
				return user.accountType >= @restriction
			end


			### Return a stringified representation of the command
			def to_s
				return "%s command (%s:%d)" % [
					self.name,
					self.sourceFile,
					self.sourceLine,
				]
			end

			#########
			protected
			#########

			### Define a singleton method for the receiver that encapsulates the
			### given command <tt>body</tt> into wrapper code for setting up the
			### necessary variables and environment and error handling. Use the
			### specified sourceFile and sourceLine for reporting errors.
			def createInvokeMethod( body, sourceFile, sourceLine )
				debugMsg( 4, "Adding #invoke method: #{body}" )

				eval %Q{
					def self.invoke( context, argString )
						#{body}
					rescue CommandError, SecurityError => e
						errmsg = "Error: %s" % e.message

						return [MUES::OutputEvent::new( errmsg + "\n" )]
					rescue => e
						errmsg = "Internal command error in %s (%s:%d): %s: %s" % [
							self.name,
							self.sourceFile,
							self.sourceLine,
							e.class.name,
							e.message
						]

						trace = []
						e.backtrace.each {|frame| trace << frame; break if frame =~ /invoke/}

						self.log.error( "Shell Error [%s]: %s\n\t%s" % [
										   context.user.username,
										   errmsg,
										   trace.join("\n\t")
									   ])

						if context.user.isImplementor?
							errmsg += "\n\t" + trace.join("\n\t")
						end

						return [MUES::OutputEvent::new( errmsg + "\n" )]
					end
				}, nil, sourceFile, sourceLine

				return true
			end

		end # class Command



		### A shell context class that is used by the MUES::CommandShell to
		### maintain command invocation context, and to provide access to
		### external objects to the command objects. The command invocation
		### context is an object which the user can set as the target of future
		### commands which expect a context. This can be used to look up an
		### object and perform multiple operations on it without requiring a new
		### lookup before every command.
		class Context < MUES::Object ; implements MUES::Debuggable

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.35 $} )[1]
			Rcsid = %q$Id: commandshell.rb,v 1.35 2003/10/13 05:16:43 deveiant Exp $


			### Create and return a new Context object with the specified shell
			### (a MUES::CommandShell object), user (a MUES::User object),
			### stream (a MUES::IOEventStream object), and
			### <tt>evalContext</tt>. The <tt>evalContext</tt> is the object
			### which is initially set as the context of commands which require
			### one.
			def initialize( shell, user, stream, evalContext )
				@shell = shell
				@user = user
				@stream = stream
				@evalContext = evalContext
				debugMsg( 2, "Initializing context object for #{@user.to_s}" )
				super()
			end


			######
			public
			######

			# The invoking MUES::CommandShell.
			attr_reader :shell

			# The invoking MUES::User.
			attr_reader :user

			# The MUES::IOEventStream object associated with the invoking
			# command shell.
			attr_reader :stream

			# The object which was last set as the command context for the
			# shell.
			attr_accessor :evalContext


		end # class Context


		# A command table class for MUES::CommandShell objects. A command table
		# is a hash-like object which contains a mapping of all available
		# command names, their synonyms, and their non-ambiguous abbreviations
		# to the corresponding command object. It also contains utility
		# functions for generating command help text, and for performing
		# approximate searches of command names.
		class CommandTable < MUES::Object ; implements MUES::Debuggable

			include MUES::TypeCheckFunctions, MUES::Factory

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.35 $} )[1]
			Rcsid = %q$Id: commandshell.rb,v 1.35 2003/10/13 05:16:43 deveiant Exp $


			### Instantiate and return a new <tt>CommandTable</tt> object which
			### contains an abbreviation mapping for the specified
			### <tt>commandObjects</tt> (an Array of MUES::CommandShell::Command
			### objects).
			def initialize( *commands )
				commands.flatten!
				checkEachType( commands, MUES::CommandShell::Command )

				debugMsg( 2, "Initializing command table with #{commands.length} commands" )
				@abbrevTable = {}
				# @soundexTable = {}
				occurrenceTable = {}

				# Build the abbrevtable (concept borrowed from the
				# Text::Abbrev Perl module by Gurusamy Sarathy
				# <gsar@ActiveState.com>)
				commands.flatten.uniq.each {|comm|

					# Iterate over all the names the command can be invoked
					# with.
					( [ comm.name ] | comm.synonyms ).each {|word|

						# Try shorter and shorter abbreviations of the command,
						# adding unambiguous ones, and deleting ones that would
						# be ambiguous (ie., because they're already in the
						# table).
						( 1 .. word.length ).to_a.reverse.each {|len|
							abbrev = word[ 0, len ]
							occurrenceTable[ abbrev ] ||= 0
							seen = occurrenceTable[ abbrev ] += 1
							
							# If this is the first occurrance, add it to the table
							if seen == 1
								@abbrevTable[ abbrev ] = comm

							# If it's the second occurrance, either delete it
							# from the table if it's an abbreviated form, or
							# just replace the abbreviation if it's the whole
							# command.
							elsif seen == 2
								if abbrev == word
									@abbrevTable[ abbrev ] = comm
								else
									@abbrevTable.delete( abbrev )
								end
							else
								break
							end
						}
					}
				}

				debugMsg( 3, "CommandTable: Abbrev table has #{@abbrevTable.keys.length} unique keys." )
				super()
			end


			### Element reference operator -- Returns the command object which
			### corresponds to the (potentially abbreviated) command name
			### <tt>name</tt>. Returns the corresponding
			### MUES::CommandShell::Command object if a one is found, or
			### <tt>nil</tt> if no command corresponds to the given name.
			def []( name )
				return @abbrevTable[ name ]
			end


			### Find and return all commands which match the specified
			### <tt>name</tt> in an approximate search.
			def approxSearch( name )
				@abbrevTable.find_all {|word,obj| word =~ /^#{name}/ }.collect {|key,val| val}.uniq
			end


			### Returns a detailed help message for the command
			### <tt>name</tt>. On success, returns a Hash of the form:
			###   {
			###		:name => 'canonical command name',
			###		:usage => "Usage description\nPossibly multiple lines.",
			###		:synonyms => ['array', 'of', 'aliases/synonyms'],
			###		:abstract => 'Command short description',
			###		:description => "Command long description.\nPossibly multiple lines.",
			###		:sourceFile => "Name of file defining the command",
			###		:sourceLine => "Line number of beginning of command definition",
			###   }
			### On failure, returns <tt>nil</tt>.
			def getHelpForCommand( name )
				if @abbrevTable.has_key?( name )
					comm = @abbrevTable[ name ]
					return {
						:name => comm.name,
						:usage => comm.usage,
						:synonyms => comm.synonyms,
						:abstract => comm.abstract,
						:description => comm.description,
						:sourceFile => comm.sourceFile,
						:sourceLine => comm.sourceLine,
					}
				else
					return nil
				end
			end


			### Returns a hash of commands to descriptions suitable for building
			### a command help table
			def getHelpTable
				table = {}
				@abbrevTable.values.uniq.each {|comm|
					table[comm.name] = [comm.abstract, comm.synonyms]
				}
				return table
			end

		end # class CommandTable


		### A parser for command definitions. An example command definition for
		### the 'gc' command:
		###   = gc
		###   
		###   == Restriction
		###   admin
		###   
		###   == Usage
		###     gc
		###   
		###   == Abstract
		###   Start Ruby's garbage-collector.
		###   
		###   == Description
		###   
		###   Start the Ruby garbage collector manually, possibly reclaiming the memory
		###   occupied by objects which have gone out of scope. Note that this is never
		###   necessary for the purposes of memory management -- Ruby does this by itself
		###   without any intervention -- but it can sometimes help in tracking down bugs to
		###   be able to start the GC explicitly.
		###   
		###   == Code
		###   
		###     return [ OutputEvent.new( "Starting garbage collection.\n\n" ),
		###   	  	   GarbageCollectionEvent.new ]
		###   
		### == To Do
		### * Enumerate the sections, and describe the contents of each, defaults, etc.
		###
		### For more examples, see the end of the
		### lib/mues/filters/CommandShell.rb file, or the contents of the
		### server/shellCommands directory, which, incidently, is the default
		### place to put new commands to be loaded.
		class CommandParser < MUES::Object ; implements MUES::Debuggable
			
			include MUES::TypeCheckFunctions, MUES::Factory

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.35 $} )[1]
			Rcsid = %q$Id: commandshell.rb,v 1.35 2003/10/13 05:16:43 deveiant Exp $


			### Instantiate and return a parser object which will create command
			### objects from the specified class (which should be either
			### MUES::CommandShell::Command or one of its derivatives).
			def initialize( commandClass=MUES::CommandShell::Command )
				@commandClass = commandClass
				super()
			end


			### Returns a Regexp object which matches the filename of a command
			### parseable by the parser.
			def fileSpec
				%r{\.cmd$}
			end


			### Parse the specified <tt>sourceFile</tt>, which should be a file
			### containing one or more command definitions, and return the
			### MUES::CommandShell::Command objects defined therein.
			def parse( sourceFile )
				checkType( sourceFile, ::String )
				data = nil

				debugMsg( 2, "Parsing commands from #{sourceFile}" )
				data = File::open( sourceFile, "r" ).readlines
				debugMsg( 3, "...read %d lines." % data.length )

				return parseData( data, sourceFile )
			end


			#########
			protected
			#########

			### Parse the specified command-definition <tt>data</tt>, which is
			### an Array of command source, and return the
			### MUES::CommandShell::Command objects specified therein.
			def parseData( data, sourceName="(Anonymous Array)" )
				checkType( data, Array )
				commands = []

				lineCount = 0

				begin
					name = nil
					sourceLine = lineCount
					sections = Hash::new("")
					sections[:restriction] = 'user'
					sections[:synonyms] = []
					#sections[:includes] = []
					currentSection = ''

					# Read a line at a time, defining the variables for
					# building the command along the way.
					data.each {|line|

						lineCount += 1
						case line

						# Skip comment lines
						when /^\s*#.*$/
							debugMsg( 5, "Skipping comment line" )
							next

						# A command header (command name)
						when /^=\s*(\w+)/
							newName = $1
							debugMsg( 4, "Found start of command '#{newName}'" )

							if name
								debugMsg( 2, "Finished parsing the '#{name}' command. Creating command object." )

								commands.push createCommand( name, sourceName, sourceLine, sections )
							end

							# Initialize the command variables that we expect to
							# parse.
							name = newName
							sourceLine = lineCount
							sections.clear
							sections[:restriction] = 'user'
							sections[:synonyms] = []
							#sections[:includes] = []
							currentSection = ''

						# Section declaration
						when /^==\s*(\w+)/i
							currentSection = $1.downcase.intern
							debugMsg( 4, "Found section header. Set current section to '#{currentSection}'" )

						# A regular line
						else

							# Parse the line according to which section we're in
							case currentSection
							when :abstract
								next unless line =~ /\S/
								debugMsg( 5, "Appending '#{line.strip}' to the abstract." )
								sections[:abstract] = line.strip

							when :restriction
								next unless line =~ /\S/
								sections[:restriction] = line.strip
								debugMsg( 5, "Setting restriction to '#{sections[:restriction]}'." )

							when :synonyms
								next unless line =~ /\S/
								sections[:synonyms] |= line.strip.split(/\s*[,;]\s*/)
								debugMsg( 3, "Added synonyms. Now: #{sections[:synonyms].inspect}" )

							when :description
								if line =~ /^\s+/
									next if sections[:description].empty?
									debugMsg( 5, "Adding paragraph break to description." )
									sections[:description] += "\n\n" unless 
										sections[:description][-1] == "\n"
								else
									debugMsg( 5, "Adding '#{line.strip}' to description." )
									sections[:description] += line.strip + " "
								end

							when :usage
								debugMsg( 5, "Adding '#{line.strip}' to usage." )
								sections[:usage] += line

							#when :includes
							#	next unless line =~ /\S/
							#	debugMsg( 5, "Adding '#{line.strip}' to the list of includes" )
							#	sections[:includes] |= line.strip.split(/\s*[,;]\s*/)

							when :code
								next unless line =~ /\S/
								debugMsg( 5, "Adding '#{line.strip}' to code." )
								sections[:code] += line
								sections[:code].untaint

							else
								debugMsg( 5, "Skipping out-of-section or unsupported section line '#{line}'" )
							end

						end
					}

					commands.push createCommand( name, sourceName, sourceLine, sections )

				rescue => e
					raise( e, e.message + " at line #{lineCount}", caller )
				end

				return commands
			end


			### Create an instance of the configured command class with the
			### specified <tt>name</tt>, <tt>sourceName</tt>,
			### <tt>sourceLine</tt>, and <tt>sections</tt>.
			def createCommand( name, sourceName, sourceLine, sections )
				body = sections[:code]
				raise CommandDefinitionError, "No invocation body." unless
					body =~ /\S+/
				debugMsg( 5, "Evaluating #{body} as the invocation body." )

				@commandClass.new( name, sourceName, sourceLine, sections, body )
			end


		end # class CommandParser


		### A command-shell creation factory. Instances of this class create and
		### combine instances of MUES::CommandShell and
		### MUES::CommandShell::CommandTable, or derivatives thereof as
		### specified by the configuration, and then maintain a list of commands
		### loaded from a configured list of directories, reloading any that
		### change via a scheduled event in the Engine to which it belongs.
		class Factory < MUES::Object ; implements MUES::Debuggable, Observable

			include MUES::TypeCheckFunctions, MUES::ServerFunctions

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.35 $} )[1]
			Rcsid = %q$Id: commandshell.rb,v 1.35 2003/10/13 05:16:43 deveiant Exp $

			### Class globals
			DefaultShellClass	= MUES::CommandShell
			DefaultTableClass	= MUES::CommandShell::CommandTable
			DefaultParserClass	= MUES::CommandShell::CommandParser

			### Create and return a new CommandFactory, configured with the
			### specified <tt>commandPath</tt> and <tt>shellParameters</tt>. The
			### classes that will be used in construction can be specified with
			### the <tt>shellClass</tt>, <tt>tableClass</tt>, and
			### <tt>parserClass</tt> arguments, which can be either the class
			### object or a name suitable for passing to the appropriate
			### factory's #create method. They default to MUES::CommandShell,
			### MUES::CommandShell::CommandTable, and
			### MUES::CommandShell::CommandParser, respectively.
			def initialize( commandPath=[], shellParameters={},
						    shellClass=DefaultShellClass,
						    tableClass=DefaultTableClass,
						    parserClass=DefaultParserClass )
				checkType( commandPath, ::Array )
				checkType( shellParameters, ::Hash, ::NilClass )
				checkType( shellClass, ::Class, ::String, ::NilClass )
				checkType( tableClass, ::Class, ::String, ::NilClass )
				checkType( parserClass, ::Class, ::String, ::NilClass )

				# Classes used to build a shell
				@shellClass			= shellClass || DefaultShellClass
				@tableClass			= tableClass || DefaultTableClass
				@parserClass		= parserClass || DefaultParserClass
				@shellParameters	= shellParameters || {}

				# Command objects are kept in a Hash so we can detect collisions
				# early.
				@registry			= {}
				@registryIsBuilt	= false
				@mutex				= Sync.new
				@commandLoadTime	= Time.at(0) # Set initial load time to epoch
				@parser				= CommandParser::create( @parserClass,
															 MUES::CommandShell::Command )

				# Set the reload interval to 10 minutes
				@reloadInterval		= -600

				# Fully-qualify all the directories in the command path
				unless commandPath.nil? || commandPath.empty?
					@commandPath = commandPath.collect {|dir|
						File.expand_path( dir )
					}.find_all {|dir|
						File.exists?( dir ) && File.directory?( dir )
					}
				end
				
				buildCommandRegistry()
				return self
			end


			######
			public
			######

			# The registry of all loaded commands, keyed by command and alias
			attr_reader		:registry

			# Flag that indicates whether or not the factory's registry of
			# commands has been built.
			attr_reader		:registryIsBuilt
			alias :registryIsBuilt? :registryIsBuilt

			# The Array of directories to search for command source files
			attr_accessor	:commandPath

			# The number of seconds to use as the interval for scheduling
			# reloads (in the format understood by MUES::Engine#scheduleEvents).
			attr_accessor	:reloadInterval
			
			# The class of objects that will be used by the factory for the shell itself.
			attr_accessor	:shellClass

			# The class of objects that will be used by the factory for the
			# shell's command table.
			attr_accessor	:tableClass

			# The class of object that will be used by the factory to parse
			# command definitions.
			attr_accessor	:parserClass



			### Returns a instance of MUES::CommandShell or one of its
			### derivatives (as specified by the configuration which created the
			### factory) tailored for the specified user (a MUES::User object).
			def createShellForUser( user )
				table = createCommandTableForUser( user )
				shell = CommandShell::create( @shellClass, user, table, @shellParameters )
				add_observer( shell )

				return shell
			end


			### Returns a MUES::CommandShell::CommandTable filled with the
			### commands that are allowed for the specified <tt>user</tt> (a
			### MUES::User object).
			def createCommandTableForUser( user )
				commands = getCommandsAvailableToUser( user )
				return CommandTable::create( @tableClass, *commands )
			end


			### Returns the MUES::CommandShell::Command objects that are
			### available to the given <tt>user</tt> (a MUES::User object) based
			### on her user account type.
			def getCommandsAvailableToUser( user )
				self.registry.values.find_all {|c| c.canBeUsedBy?(user)}
			end


			### Build the command registry for this factory.
			def buildCommandRegistry
				@mutex.synchronize( Sync::EX ) {

					# If the registry's already been built, unset the
					# appropriate flag. Only log if it's being built for the
					# first time to avoid spamming the log if the update cycle
					# is small.
					if @registryIsBuilt
						@registryIsBuilt = false
					else
						self.log.notice( "Building command registry" )
					end
					loadCommandsIntoRegistry()
				}

				return []
			end
			alias_method :rebuildCommandRegistry, :buildCommandRegistry


			#########
			protected
			#########

			### Find commands newer than the last time the registry was build,
			### load them, and insert the commands into the Factory's
			### registry. Returns the number of commands that were successfully
			### (re)loaded.
			def loadCommandsIntoRegistry
				commands = nil

				@mutex.synchronize(Sync::EX) {

					# Get the list of updated commands and derive the list of
					# their sources
					commands = loadNewCommands()
					unless commands.empty?

						self.log.notice "Loading %d new/reloaded commands into the "\
						"CommandFactory's registry" % commands.length

						# Remove old commands loaded from the modified sources (so
						# deleting a command from sources works)
						sources = commands.collect {|cmd| cmd.sourceFile}.sort.uniq
						@registry.delete_if {|k,v| sources.include? v.sourceFile}

						# Insert new versions of the commands into the registry,
						# checking for collisions.
						commands.each {|command|

							# Iterate over the command name and any associated aliases
							[ command.name, command.synonyms ].flatten.compact.each {|name|

								# Test for collision
								if @registry.has_key?( name )
									raise CommandNameConflictError,
										"Command '%s' has clashing implementations in %s:%d and %s:%d " % [
										name,
										@registry[name].sourceFile, @registry[name].sourceLine,
										command.sourceFile, command.sourceLine
									]
								end

								# Install the command into the command registry
								@registry[ name ] = command
							}
						}

						self.changed( true )
					end

					@registryIsBuilt = true
				}

				self.notify_observers( self )
				return commands.length
			end


			### Iterate over each file in the shell commands directory specified
			### in the configuration, parsing the ones that have changed since
			### last we loaded, and returning an Array of resulting
			### MUES::CommandShell::Command objects.
			def loadNewCommands
				commands = nil

				# Parse all command files in the configured directories newer
				# than our last load time.
				@mutex.synchronize( Sync::EX ) {

					# Get the old load time for comparison and set it to the
					# current time
					oldLoadTime = @commandLoadTime
					@commandLoadTime = Time.now

					debugMsg 2, "Loading commands newer than #{oldLoadTime.to_s}"

					# Load the default commands defined at the end of this file.
					commands = []
					if File.mtime(__FILE__) > oldLoadTime
						self.log.info( "(Re)loading built-in commands from %s" % __FILE__ )
						commands += @parser.parse( __FILE__ )
					end
					
					# Find any files that have changed
					newFiles = findUpdatedCommandFiles( oldLoadTime )

					# Now if any newer files were found, load commands from
					# them.
					newFiles.each {|fqf|
						fqf.untaint
						self.log.info( "(Re)loading commands from '#{fqf}'" )
						begin
							commands += @parser.parse( fqf )
						rescue SyntaxError => e
							self.log.error "Syntax error in command file '%s': %s:\n\t%s" %
								[ fqf, e.message, e.backtrace.join("\t\n") ]
						rescue => e
							self.log.error "Unknown error while parsing command file '%s': %s:\n\t%s" %
								[ fqf, e.message, e.backtrace.join("\t\n") ]
						end
					}
				}

				return commands.flatten
			end


			### Find and return an Array of the fully-qualified paths to any
			### command files under the factory's command path that are newer
			### than <tt>oldLoadTime</tt>.
			def findUpdatedCommandFiles( oldLoadTime )
				# Get the target filespec from the parser
				fileSpec = @parser.fileSpec
				fileSpec.untaint
				debugMsg( 2, "File spec is: #{fileSpec.inspect}" )

				# Search each directory in the path, top-down, for command
				# files newer than our last load time, loading any we
				# find.
				newFiles = []
				return newFiles if @commandPath.empty?

				@commandPath.each {|cmdsdir|
					cmdsdir.untaint
					self.log.info( "Looking for updated commands in '#{cmdsdir}'." )
					Find.find( cmdsdir ) {|f|
						f.untaint
						Find.prune if f =~ %r{^\.} # Ignore hidden stuff

						# Turn the filename into its fully-qualified version
						fqf = File::expand_path( f, cmdsdir )
						fqf.untaint

						if fileSpec.match(fqf) && File.file?(fqf) && File.mtime(fqf) > oldLoadTime
							debugMsg 3, "Found updated file '#{fqf}'"
							newFiles.push( fqf )
						end
					}
				}

				return newFiles
			end

		end # class Factory

			
	end # class CommandShell
end # module MUES




#############################################################
###	D E F A U L T   B A R E B O N E S   C O M M A N D S  
#############################################################
__END__


### Quit command
= quit

== Abstract
Disconnect from the server.

== Description
This command diconnects the user from the server, severing any connections to
the worlds hosted there.

== Usage
  quit

== Synonyms
logout

== Code

  # Turn off the user's prompt
  context.shell.vars['prompt'] = ''

  return [
	MUES::OutputEvent::new( ">>> Logging out <<<\n" ),
	MUES::UserLogoutEvent::new( context.user )
  ]


### 'Debug' command
= debug

== Restriction
implementor

== Abstract
Set the debug level of an object.

== Description

Sets the debugging level of any object in the system by Ruby id. The list of
available objects can be viewed via the '/objects' command. If no level is
specified, the object's current debug level is displayed.

== Usage
  debug <id> [<level>]

== Code
  if argString =~ /^(\d+)$/
	  targetId = $1.to_i

	  output = ''
	  targetObject = MUES::UtilityFunctions::getObjectByRubyId( targetId )
	  if targetObject.nil?
		output = "Couldn't find an object with id = %d" % targetId
	  elsif !( targetObject.class < MUES::Debuggable )
		output = "%s (%s) is not debuggable." % [
			MUES::UtilityFunctions::trimString(targetObject.inspect),
			targetId
		]
	  else
		output = "Debugging level for %s is currently %d" % [
			MUES::UtilityFunctions::trimString(targetObject.inspect),
			targetObject.debugLevel.to_i
		]
	  end

	  return [OutputEvent.new( output + "\n\n" )]
  elsif argString =~ /^(\d+)\s*=?\s*(\d)$/
	  targetId, level = $1.to_i, $2.to_i

	  output = ''
	  targetObject = MUES::UtilityFunctions::getObjectByRubyId( targetId )
	  if targetObject.nil?
		output = "Couldn't find an object with id = %d" % targetId
	  elsif !( targetObject.class < MUES::Debuggable )
		output = "%s (%s) is not debuggable." % [
			MUES::UtilityFunctions::trimString(targetObject.inspect),
			targetId
		]
	  else
		output = "Setting debugging level for %s to %d" % [
			MUES::UtilityFunctions::trimString(targetObject.inspect),
			level
		]
		targetObject.debugLevel = level
	  end

	  return [OutputEvent.new( output + "\n\n" )]

  else
	  raise CommandError, self.usage
  end



### 'Set' command
= set

== Abstract
Set shell parameters.

== Description
View, get, or set shell parameters. The first form will display a list of the
shell parameters which are currently defined, while the second displays the
value set for only the specified parameter. The third form set the given
parameter to the specified value, creating the parameter if necessary.

== Usage
  set
  set <param>
  set <param> = <value>

== Code

  results = []

  case argString

  ### <param> = <value> form (set)
  when /(\w+)\s*=\s*(.*)/

	  param = $1
	  value = $2

	  # Strip enclosing quotes from the value
	  debugMsg 4, "Stripping quotes."
	  value.gsub!( /\s*(["'])((?:[^\1]+|\\.)*)\1/ ) {|str| $2 }
	  debugMsg 4, "Done stripping."

	  if context.shell.vars.has_key?( param )
		  results << MUES::OutputEvent.new("Setting #{param} = '#{value}'\n")
	  else
		  results << MUES::OutputEvent.new("(Created variable '#{param}') \n")
	  end

	  context.shell.vars[ param ] = value

  ### <param> form (get)
  when /(\w+)/
	  param = $1

	  if context.shell.vars.has_key?( param )
		  results << MUES::OutputEvent.new("#{param} = '#{context.shell.vars[param]}'\n")
	  else
		  results << MUES::OutputEvent.new("#{param} = nil\n")
	  end

  ### No-arg form (list)
  else
	  varlist = ''
	  if context.shell.vars.empty?
		  varlist = "(No variables set)\n"
	  else
		  varlist = "Variables:\n"
		  context.shell.vars.each {|param,val| varlist << "\t%20s = '%s'\n" % [ param, val ] }
	  end

	  results << MUES::OutputEvent.new(varlist)
  end

  return results
