#!/usr/bin/ruby
#
# This file is a collection of classes which are used in the MUES command
# shell. The command shell is a command interface for user interaction with the
# MUES::Engine. This file contains the following classes:
#
# [MUES::CommandShell]
#   The main command shell class; it is a derivative of MUES::IOEventFilter.
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
#  require "mues/filters/CommandShell"
#
# == To Do
# 
# * Perhaps add soundex matching if there are no abbrev matches for a command?
#
# * Add functions for easily defining command classes, per Red's
#   suggestion. Something like:
#
#	defCommand( :MyCommand, "mycommand", MUES::UserCommand ) {|context,args|
#		return MyCommandEvent.new( context.user )
#	}
#
# == Rcsid
# 
# $Id: commandshell.rb,v 1.16 2002/09/05 04:18:41 deveiant Exp $
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
#require "Soundex"

require "mues/Object"
require "mues/Mixins"
require "mues/Events"
require "mues/Exceptions"
require "mues/User"
require "mues/filters/IOEventFilter"

module MUES

	### Exception class for command name conflicts
	def_exception :CommandNameConflictError, "Command name conflict", Exception

	### This class is a MUES::IOEventFilter that provides connected users
	### with the ability to execute commands in the context of their
	### MUES::User object.
	class CommandShell < IOEventFilter ; implements MUES::Debuggable

		include MUES::ServerFunctions, MUES::FactoryMethods

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.16 $ )[1]
		Rcsid = %q$Id: commandshell.rb,v 1.16 2002/09/05 04:18:41 deveiant Exp $
		DefaultSortPosition = 700

		### Class globals

		# The default characters that designate an input line as a command
		@@DefaultCommandPrefix	= '/'

		# The default prompt to display when the command shell is forward
		@@DefaultPrompt			= 'mues> '


		### Return a new shell input filter for the specified user (a MUES::User
		### object).
		def initialize( user, commandTable, commandPrefix=@@DefaultCommandPrefix, prompt=@@DefaultPrompt )
			checkType( user, MUES::User )
			checkType( commandTable, MUES::CommandShell::CommandTable )

			super()
			debugMsg( 1, "Initializing command shell for #{user.to_s}." )

			@user			= user
			@commandPrefix	= commandPrefix
			@vars			= { 'prompt' => prompt }
			@commandTable	= commandTable

			# These are passed as arguments to #activate
			@stream			= nil
			@context		= nil
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
			super( stream )
			@stream = stream
			@context = Context::new( self, @user, stream, nil )
			queueOutputEvents( OutputEvent.new(@vars['prompt']) )
			debugMsg( 2, "Starting command shell for #{@user.to_s}" )
		end


		### Stop the filter for the specified stream (a MUES::IOEventStream
		### object).
		def stop( stream )
			@stream = nil
			@context = nil
			debugMsg( 2, "Stopping command shell for #{@user.to_s}" )
			super( stream )
		end


		### Handle the specified input events by comparing them to the list of
		### valid shell commands and creating the appropriate events for any
		### that match.
		def handleInputEvents( *events )
			unhandledInputEvents = []

			debugMsg( 5, "CommandShell: Got #{events.size} input events to filter." )

			### Extract commands from each event, run them if they match a
			### command we know about, and then dispatch the resultant events.
			events.flatten.each do |e|

				### If the input looks like a command for the shell, look for
				### commands we know about and take appropriate action when
				### one is found
				if e.data =~ /^#{@commandPrefix}(\w+)\b(.*)/
					command = $1
					argString = $2.strip

					results = []

					### Look up the command in the command table, trying to get
					### the specific one first
					if (( commandObj = @commandTable[command] ))
						results << commandObj.invoke( @context, argString )
					elsif ( ! (objects = @commandTable.approxSearch(command)).empty? )
						results << OutputEvent.new( "Ambiguous command '#{command}': Matches [",
												    objects.collect {|o| o.name}.join(', '), "]\n" )
					else
						results << OutputEvent.new( "No such command '#{command}'.\n" )
					end

					results.flatten!

					### Separate out all the different kinds of events for
					### proper dispatch
					output = results.find_all {|e| e.kind_of?( MUES::OutputEvent )}
					results -= output
					input = results.find_all {|e| e.kind_of?( MUES::InputEvent )}
					results -= input
					newFilters = results.find_all {|e| e.kind_of?( MUES::IOEventFilter )}
					results -= newFilters

					### Add any new filters to our parent event stream
					@stream.addFilters( *newFilters ) unless newFilters.empty?

					### Dispatch events
					unhandledInputEvents << input unless input.empty?
					queueOutputEvents( *output ) unless output.empty?
					engine.dispatchEvents( *results ) unless results.empty?

				### If the input doesn't look like a command for the shell, add
				### it to the list of input that we'll pass along to the next
				### filter.
				else
					unhandledInputEvents << e
				end

				### No matter what the input, we're responsible for the prompt,
				### so send it for each input event.
				queueOutputEvents( PromptEvent.new )
			end

			return unhandledInputEvents
		end


		#############################################################
		###	A S S O C I A T E D   O B J E C T   C L A S S E S
		#############################################################

		# The shell command object class. Commands objects are wrappers around
		# event-generating functions triggered by user input. They are loaded by
		# a MUES::CommandShell::Factory via a MUES::CommandShell::CommandParser,
		# and references to the ones which are executable by a particular
		# MUES::User are given to her MUES::CommandShell at creation. The
		# registry of commands is kept up to date by occasionally checking for
		# updated files.
		class Command < MUES::Object ; implements MUES::Debuggable

			include MUES::User::AccountType, MUES::TypeCheckFunctions

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
			def initialize( name, sourceFile, sourceLine, commandSpec, &body )
				checkType( name, ::String )
				checkType( sourceFile, ::String )
				checkType( sourceLine, ::Integer )
				checkType( commandSpec, ::Hash )
				checkType( body, ::Proc, ::Method )

				checkType( commandSpec[:abstract], ::String )
				checkType( commandSpec[:description], ::String, ::NilClass )
				checkType( commandSpec[:usage], ::String, ::NilClass )
				checkType( commandSpec[:restriction], ::String, ::Integer )
				checkType( commandSpec[:synonyms], ::Array )

				self.log.debug {"Creating a new command '#{name}' from '#{sourceFile}':#{sourceLine}"}

				@name			= name
				@sourceFile		= sourceFile
				@sourceLine		= sourceLine

				@abstract		= commandSpec[:abstract]
				@description	= commandSpec[:description] || @abstract
				@usage			= commandSpec[:usage] || @name
				@synonyms		= commandSpec[:synonyms]

				@body			= body

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


			### Invoke the command's body, returning any consequential events in
			### an Array.
			def invoke( context, argString )
				@body.call( context, argString )
			end


			### Returns true if the command can be used by the user specified (a
			### MUES::User object).
			def canBeUsedBy?( user )
				checkType( user, MUES::User )
				return user.accountType >= @restriction
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
		end # class Context


		# A command table class for MUES::CommandShell objects. A command table
		# is a hash-like object which contains a mapping of all available
		# command names, their synonyms, and their non-ambiguous abbreviations
		# to the corresponding command object. It also contains utility
		# functions for generating command help text, and for performing
		# approximate searches of command names.
		class CommandTable < MUES::Object ; implements MUES::Debuggable

			include MUES::TypeCheckFunctions, MUES::FactoryMethods

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

				### Build the abbrevtable (concept borrowed from the
				### Text::Abbrev Perl module by Gurusamy Sarathy
				### <gsar@ActiveState.com>)
				commands.flatten.uniq.each {|comm|

					( [ comm.name ] | comm.synonyms ).each {|word|

						( 1 .. word.length ).to_a.reverse.each {|len|
							abbrev = word[ 0, len ]
							occurrenceTable[ abbrev ] ||= 0
							seen = occurrenceTable[ abbrev ] += 1
							
							if seen == 1
								@abbrevTable[ abbrev ] = comm

							elsif seen == 2
								@abbrevTable.delete( abbrev )

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


			### Returns a hash of commands to descriptions suitable for building
			### a command help table
			def getHelpTable( cmdName = nil )
				if cmdName.nil?
					table = {}
					@abbrevTable.values.uniq.each {|comm|
						table[comm.name] = [comm.description, comm.synonyms]
					}
					return table
				elsif @abbrevTable.has_key?( cmdName )
					comm = @abbrevTable[ cmdName ]
					return { cmdName => [comm.description, comm.synonyms] }
				else
					return nil
				end
			end
		end # class CommandTable


		### A parser for command definitions
		class CommandParser < MUES::Object
			
			include MUES::TypeCheckFunctions, MUES::FactoryMethods

			
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

				self.log.debug {"Parsing commands from #{sourceFile}"}
				data = File::open( sourceFile, "r" ).readlines
				self.log.debug {"...read %d lines." % data.length}

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
							self.log.debug( "Skipping blank line" )
							next

						# A command header (command name)
						when /^=\s*(\w+)/
							newName = $1
							self.log.debug( "Found start of command '#{newName}'" )

							if name
								self.log.debug( "Finished parsing the '#{name}' command. Creating command object." )

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
							self.log.debug( "Found section header. Set current section to '#{currentSection}'" )

						# A regular line
						else

							# Parse the line according to which section we're in
							case currentSection
							when :abstract
								next unless line =~ /\S/
								self.log.debug( "Appending '#{line.strip}' to the abstract." )
								sections[:abstract] = line.strip

							when :restriction
								next unless line =~ /\S/
								sections[:restriction] = line.strip
								self.log.debug( "Setting restriction to '#{sections[:restriction]}'." )

							when :synonyms
								next unless line =~ /\S/
								sections[:synonyms] |= line.strip.split(/\s*[,;]\s*/)
								self.log.debug { "Added synonyms. Now: #{sections[:synonyms].inspect}" }

							when :description
								if line =~ /^\s+/
									next if sections[:description].empty?
									self.log.debug( "Adding paragraph break to description." )
									sections[:description] += "\n\n" unless 
										sections[:description][-1] == "\n"
								else
									self.log.debug( "Adding '#{line.strip}' to description." )
									sections[:description] += line.strip + " "
								end

							when :usage
								self.log.debug( "Adding '#{line.strip}' to usage." )
								sections[:usage] += line

							#when :includes
							#	next unless line =~ /\S/
							#	self.log.debug( "Adding '#{line.strip}' to the list of includes" )
							#	sections[:includes] |= line.strip.split(/\s*[,;]\s*/)

							when :code
								next unless line =~ /\S/
								self.log.debug( "Adding '#{line.strip}' to code." )
								sections[:code] += line

							else
								self.log.debug( "Skipping out-of-section or unsupported section line '#{line}'" )
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
				body = "Proc::new {|context,argString| " + sections[:code] + "}"
				self.log.debug {"Evaluating #{body} as the command body."}
				bodyProc = eval body

				cmd = @commandClass.new( name, sourceName, sourceLine, sections, &bodyProc )

				# Eval the required includes in the context of the command
				#unless sections[:includes].empty?
				#	includeEval = sections.[:includes].collect {|mod|
				#		"include #{mod}"
				#	}.join('; ')
				#	cmd.instance_eval includeEval
				#end
			end


		end # class CommandParser


		### A command-shell creation factory. Instances of this class create and
		### combine instances of MUES::CommandShell and
		### MUES::CommandShell::CommandTable, or derivatives thereof as
		### specified by the configuration, and then maintain a list of commands
		### loaded from a configured list of directories, reloading any that
		### change via a scheduled event in the Engine to which it belongs.
		class Factory < MUES::Object

			include MUES::TypeCheckFunctions, MUES::ServerFunctions

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.16 $ )[1]
			Rcsid = %q$Id: commandshell.rb,v 1.16 2002/09/05 04:18:41 deveiant Exp $

			### Class globals
			@@DefaultShellClass		= MUES::CommandShell
			@@DefaultTableClass		= MUES::CommandShell::CommandTable
			@@DefaultParserClass	= MUES::CommandShell::CommandParser

			### Create and return a new CommandFactory according to the
			### commandshell configuration of the specified <tt>config</tt> (a
			### MUES::Config object).
			def initialize( config )
				checkType( config, MUES::Config )

				@config				= config

				# Classes used to build a shell
				@shellClass			= config.commandshell['class'] || @@DefaultShellClass
				@tableClass			= config.commandshell['tableclass'] || @@DefaultTableClass
				@parserClass		= config.commandshell['parserclass'] || @@DefaultParserClass

				# Command objects are kept in a Hash so we can detect collisions
				# early.
				@registry			= {}
				@registryIsBuilt	= false
				@mutex				= Sync.new
				@commandLoadTime	= Time.at(0) # Set initial load time to epoch
				@parser				= CommandParser::create( @parserClass,
															 MUES::CommandShell::Command )

				@reloadInterval		= -30

				# Fully-qualify all the directories in the command path
				@commandPath = @config.commandshell.commandPath.collect {|dir|
					File.expand_path( dir )
				}.find_all {|dir|
					File.exists?( dir ) && File.directory?( dir )
				}
				
				buildCommandRegistry()

				# Schedule an event to periodically update commands
				@reloadEvent = CallbackEvent.new( self.method('rebuildCommandRegistry') )
				engine.scheduleEvents( @reloadInterval, @reloadEvent )

				return self
			end


			######
			public
			######

			# The Array of directories to search for command source files
			attr_reader :commandPath

			# The registry of all loaded commands, keyed by command and alias
			attr_reader :registry


			### Returns a instance of MUES::CommandShell or one of its
			### derivatives (as specified by the configuration which created the
			### factory), tailored for the specified user (a MUES::User object).
			def createShellForUser( user )
				table = createCommandTableForUser( user )
				return CommandShell::create( @shellClass, table,
											 config.commandshell['command_prefix'],
											 config.commandshell['prompt'] )
				
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


			### Iterate over each file in the shell commands directory specified
			### in the configuration, parsing the ones that have changed since
			### last we loaded, and returning an Array of resulting
			### MUES::CommandShell::Command objects.
			def loadCommands

				commands = nil

				### Parse all command files in the configured directories newer
				### than our last load time.
				@mutex.synchronize( Sync::EX ) {

					# Get the old load time for comparison and set it to the
					# current time
					oldLoadTime = @commandLoadTime
					@commandLoadTime = Time.now

					self.log.info( "Loading commands newer than #{@commandLoadTime.to_s}" )

					# Get the target filespec from the parser
					fileSpec = @parser.fileSpec
					self.log.debug { "File spec is: #{fileSpec.inspect}" }

					# Load the default commands defined at the end of this file.
					commands = @parser.parse( __FILE__ )
					
					### Search each directory in the path, top-down, for command
					### files newer than our last load time, loading any we
					### find.
					@commandPath.each {|cmdsdir|
						self.log.info( "Looking for updated commands in '#{cmdsdir}'." )
						Find.find( cmdsdir ) {|f|
							Find.prune if f =~ %r{^\.} # Ignore hidden stuff

							# Turn the filename into its fully-qualified version
							fqf = File::expand_path( f, cmdsdir )

							if fileSpec.match(fqf) && File.file?(fqf) && File.mtime(fqf) > oldLoadTime
								self.log.debug( "Loading commands from '#{fqf}'" )
								commands += @parser.parse( fqf )
							end
						}
					}
				}

				return commands.flatten
			end


			### Build the command registry for this factory
			def buildCommandRegistry
				
				@mutex.synchronize(Sync::EX) {
					return true if @registryIsBuilt
					self.log.notice( "Building command registry" )

					# Get the list of updated commands and derive the list of
					# their sources
					commands = loadCommands()
					self.log.notice( "Got %d new/reloaded commands" % commands.length )

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
									@registry[name].sourceName, @registry[name].sourceLine,
									command.sourceName, command.sourceLine
								]
							end

							# Install the command into the command registry
							@registry[ name ] = command
						}
					}

					@registryIsBuilt = true
				}

				return true
			end


			### Rebuild the command registry after checking for
			### updates. Uses the specified <tt>config</tt> object to
			### determine what directories to load commands from.
			def rebuildCommandRegistry
				self.log.notice( 2, "Flushing command registry for rebuild at #{Time.now}" )
				@mutex.synchronize( Sync::EX ) {
					@registryIsBuilt = false
					buildCommandRegistry()
				}
			end

		end

			
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
the worlds hosted theree.

== Usage
  quit

== Synonyms
logout

== Code

  return [ MUES::UserSaveEvent.new( context.user ), MUES::UserLogoutEvent.new( context.user ) ]



### Help command
= help

== Abstract
Fetch help about a command or all commands.

== Usage
  help [<command>]

== Code

  helpTable = nil
  rows = []

  ### Fetch the help table from the shell's command table
  if args =~ %r{(\w+)}
	  helpTable = context.shell.commandTable.getHelpTable( $1 )

	  # If there was no help available, just output a message to
	  # that effect
	  return OutputEvent.new( "No help found for '#{$1}'\n" ) if helpTable.nil?

	  rows << "Help for '#{$1}':\n"
  else
	  helpTable = context.shell.commandTable.getHelpTable()
	  rows << "Help topics:\n"
  end

  ### Add a row or two for each table entry
  helpTable.sort.each {|cmd,desc|
	  rows << "\t%20s : %s" % [ cmd, desc[0] ]
	  rows << " [Synonyms: %s]" % desc[1].join(', ') unless desc[1].empty?
	  rows << "\n"
  }

  rows << "\n"
  return OutputEvent.new( rows )


### 'Roles' command
= roles

== Abstract
List available roles in the specified environments.

== Usage
  roles [<environment names>]

== Code

  results = []
  envNames = []
  list = nil

  ### If they passed at least one environment name, parse them out
  ### of the line.
  if args =~ %r{\w}
	  envNames = args.scan(/\w+/)
  else
	  envNames = engine().getEnvironmentNames
  end

  list = "\n"
  roleCount = 0
  envNames.each {|envName|

	  ### Look for the roles in the requested environment. Catch any
	  ### problems as exceptions, and turn them into error messages
	  ### for output.
	  begin
		  env = engine().getEnvironment( envName ) or
			  raise CommandError, "No such environment '#{envName}'."
		  list << "%s (%s)\n" % [ envName, env.class.name ]
		  env.getAvailableRoles( context.user ).each {|role|
			  list << "    #{role.to_s}\n"
			  roleCount += 1
		  }
	  rescue CommandError, SecurityViolation => e
		  list << e.message + "\n"
	  end

	  list << "\n"
  }

  list << "(#{roleCount}) role/s currently available to you.\n\n"

  results << OutputEvent.new( list )
  return results.flatten



### 'Connect' command
= connect

== Synonyms
play

== Abstract
Connect to the specified environment in the specified role.

== Usage
  connect [to] <environment> [as] <role>

== Code

  results = []
  if args =~ %r{(?:\s*to\s*)?(\w+)\s+(?:as\s*)?(\w+)}
	  envName, roleName = $1, $2

	  ### Look for the requested role in the requested
	  ### environment, returning the new filter object if we find
	  ### it. Catch any problems as exceptions, and turn them into
	  ### error messages for output.
	  begin
		  env = engine().getEnvironment( envName ) or
			  raise CommandError, "No such environment '#{envName}'."
		  role = env.getAvailableRoles( context.user ).find {|role|
			  role.name == roleName
		  }
		  raise CommandError, "Role '#{roleName}' is not currently available to you." unless
			  role.is_a?( MUES::Role )

		  results << OutputEvent.new( "Connecting..." )
		  results << env.getParticipantProxy( context.user, role )
		  results << OutputEvent.new( "connected.\n\n" )
	  rescue CommandError, SecurityViolation => e
		  results << OutputEvent.new( e.message )
	  end
  else
	  results << OutputEvent.new( usage() )
  end

  return results.flatten



### 'Disconnect' command
= disconnect

== Abstract
Disconnect from the specified role in the specified environment.

== Usage
  disconnect [<role> [in]] <environment>

== Code

  results = []
  roleName = nil
  envName = nil

  ### Parse the arguments, returning a usage message if we can't
  ### parse
  if args =~ %r{(\w+)\s+(?:in\s*)?(\w+)}
	  roleName, envName = $1, $2
  elsif args =~ %r{(\w+)}
	  envName = $1
  else
	  return [ OutputEvent.new( usage() ) ]
  end

  ### Look for a proxy from the specified environment
  begin
	  targetEnv = engine().getEnvironment( envName ) or
		  raise CommandError, "No such environment '#{envName}'."
	  targetProxy = context.stream.findFiltersOfType( MUES::ParticipantProxy ).find {|f|
		  f.env == targetEnv && ( roleName.nil? || f.role.name == roleName )
	  } or raise CommandError, "Not connected to #{envName} #{roleName ? 'as ' + roleName : ''}"

	  results << OutputEvent.new( "Disconnecting from #{envName}..." )
	  targetEnv.removeParticipantProxy( targetProxy )
	  context.stream.removeFilters( targetProxy )
	  results << OutputEvent.new( " disconnected.\n\n" )
  rescue CommandError, SecurityViolation => e
	  results << OutputEvent.new( e.message )
  end

  return results.flatten


### 'Debug' command
= debug

== Restrictions
implementor

== Abstract
Set command shell debug level.

== Usage
  debug [<level>]

== Code
  if args =~ /=\s*(\d)/
	  level = $1
	  context.shell.debugLevel = level.to_i
	  return OutputEvent.new( "Setting shell debug level to #{level}.\n" )

  else
	  return OutputEvent.new( "Shell debug level is currently #{context.shell.debugLevel}.\n" )
  end



### 'Eval' command
= eval

== Restrictions
admin

== Abstract
Evaluate the specified ruby code in the current object context.

== Usage
  eval <code>

== Code
  contextObject = context.evalContext

  rval = nil
  begin
	  res = contextObject.instance_eval( args.strip, '<shell input>', 1 )
	  rval = "=> #{res.inspect}\n\n"
  rescue StandardError, ScriptError => e
	  rval = ">>> Eval error: #{e.to_s}\n\n"
  end

  return MUES::OutputEvent.new( rval )



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

  case args

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

  return *results
