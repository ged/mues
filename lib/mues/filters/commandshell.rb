#!/usr/bin/ruby
#################################################################
=begin

=CommandShell.rb

== Name

CommandShell - a MUES command shell input filter class

== Synopsis

  require "mues/filters/CommandShell"

== Description

This is a command shell input filter class. It provides a simple shell for
interacting with the MUES Engine after logging in.

This module provides (({MUES::CommandShell})) -- a subclass of
(({MUES::IOEventFilter})), base command classes
((({MUES::ShellCommand::Command})), (({MUES::ShellCommand::UserCommand})),
(({MUES::ShellCommand::CreatorCommand})),
(({MUES::ShellCommand::ImplementorCommand})), and
(({MUES::ShellCommand::AdminCommand}))), as well as several concrete barebones
shell command classes.

== Classes
=== (({MUES::CommandShell}))

This an IOEventFilter class that provides connected users with the ability to
execute commands in the context of the Engine.

=== (({MUES::ShellCommand::Command}))

This is an abstract base class for shell commands, which are functions triggered
by user input. They are loaded the first time a shell is created, and are kept
up to date by occasionally checking for updated files.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

== To Do

* Perhaps add soundex matching if there are no abbrev matches for a command?

=end
#################################################################

require "sync"
require "singleton"
require "find"
#require "Soundex"

require "mues/Namespace"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

module MUES

	### Exception class
	def_exception :CommandNameConflictError, "Command name conflict", Exception

	### Command shell class
	class CommandShell < IOEventFilter ; implements Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: commandshell.rb,v 1.6 2001/07/27 04:12:46 deveiant Exp $
		DefaultSortPosition = 700

		### Class attributes
		@@DefaultCommandString	= '/'
		@@DefaultPrompt			= 'mues> '
		@@Instances				= 0

		# A finalizer proc to unschedule the ReloadCommandsEvent if there aren't
		# any more instances.
		@@Finalizer = Proc.new {
			@@InstanceCount -= 1
		}


		#############################################################
		###	P R O T E C T E D   M E T H O D S
		#############################################################

		### (PROTECTED) METHOD: initialize( aUser )
		### Initialize a new shell input filter for the specified user
		protected
		def initialize( aUser )
			super()
			@user = aUser
			@commandString = @@DefaultCommandString
			@context = nil
			@vars = { 'prompt' => @@DefaultPrompt }

			@commandTable = CommandTable.new( Command.getPermissableCommands(aUser) )

			@stream = nil

			@@Instances += 1
			ObjectSpace.define_finalizer( self, @@Finalizer )
		end


		#############################################################
		###	P U B L I C   M E T H O D S
		#############################################################
		public

		### Accessors
		attr_accessor	:vars, :commandString
		attr_reader		:user, :commandTable


		### METHOD: start( aStream=MUES::IOEventStream )
		### Start the filter .
		def start( stream )
			@stream = stream
			@context = Context.new( self, @user, stream, nil )
			queueOutputEvents( OutputEvent.new(@vars['prompt']) )
			super( stream )
		end


		### METHOD: stop( aStream=MUES::IOEventStream )
		### Stop the filter.
		def stop( stream )
			@stream = nil
			@context = nil
			super( stream )
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
				if e.data =~ /^#{@commandString}(\w+)\b(.*)/
					command = $1
					argString = $2

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
				queueOutputEvents( OutputEvent.new(@vars["prompt"]) )
			end

			return unhandledInputEvents
		end


		#############################################################
		###	A S S O C I A T E D   O B J E C T   C L A S S E S
		#############################################################

		### CommandShell Context object class
		class Context < MUES::Object
			attr_reader :shell, :user, :stream
			attr_accessor :evalContext
			def initialize( shell, user, stream, evalContext )
				@shell = shell
				@user = user
				@stream = stream
				@evalContext = evalContext
			end
		end # class Context

		### CommandTable class
		class CommandTable < MUES::Object

			### METHOD: new( commandObjects )
			def initialize( commands )
				checkType( commands, Array )
				@abbrevTable = {}
				# @soundexTable = {}
				occurrenceTable = {}

				### Build the abbrevtable (concept borrowed from Text::Abbrev by
				### Gurusamy Sarathy <gsar@ActiveState.com>)
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
			end

			### METHOD: [ name ]
			def []( name )
				return @abbrevTable[ name ]
			end

			### METHOD: approxSearch( name )
			def approxSearch( name )
				@abbrevTable.find_all {|word,obj| word =~ /^#{name}/ }.collect {|key,val| val}.uniq
			end

			### METHOD: getHelpTable( [commandName] )
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


		### Base command class
		class Command < MUES::Object ; implements AbstractClass, Debuggable, Notifiable

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
			Rcsid = %q$Id: commandshell.rb,v 1.6 2001/07/27 04:12:46 deveiant Exp $

			### Class values
			@@CommandRegistry	= {}
			@@RegistryIsBuilt	= false
			@@CommandMutex		= Sync.new
			@@CommandLoadTime	= Time.at(0) # Set initial load time to epoch
			@@ChildClasses		= []

			# Scheduled event to periodically update commands
			@@ReloadEvent		= nil
			@@ReloadInterval	= -30
			@@Instances			= {}

			private_class_method :new

			### Class methods
			class << self

				### (CLASS) METHOD: instance()
				### Returns the instance of the command class, as it's a singleton
				def instance
					@@Instances[ self ] ||= new()
				end

				### (CLASS) METHOD: atEngineStartup( theEngine=MUES::Engine )
				### Notification method (Notifiable interface) to register
				### update callback event after the engine is started.
				def atEngineStartup( theEngine )
					buildCommandRegistry( theEngine.config )
					@@ReloadCommandsEvent = CallbackEvent.new( self.method('rebuildCommandRegistry'), theEngine.config )
					theEngine.scheduleEvents( @@ReloadInterval, @@ReloadCommandsEvent )
					LogEvent.new( "notice", "Command registry built and rebuild event scheduled" );
				end


				### (CLASS) METHOD: atEngineShutdown( theEngine=MUES::Engine )
				### Notification method (Notifiable interface) to un-register
				### update callback event when the engine is about to shut down.
				def atEngineShutdown( theEngine )
					theEngine.cancelScheduledEvents( @@ReloadCommandsEvent )
					LogEvent.new( "notice", "Command registry rebuild event cancelled" );
				end


				### (CLASS) METHOD: loadCommands( config=MUES::Config )
				### Iterate over each file in the shell commands directory, loading
				### each one and recording its mtime so we can tell if it changes.
				def loadCommands( config )
					checkType( config, MUES::Config )
					cmdsdir = config["CommandShell"]["CommandsDir"] or
						raise Exception "No commands directory configured!"

					### Load all ruby source in the configured directory newer
					### than our last load time. Each child will be registered
					### in the @@ChildClasses array as it's loaded (assuming
					### it's implemented correctly -- if it isn't, we don't much
					### care).
					@@CommandMutex.synchronize( Sync::EX ) {

						# Get the old load time for comparison and set it to the
						# current time
						oldLoadTime = @@CommandLoadTime
						@@CommandLoadTime = Time.now
						
						### Search top-down for ruby files newer than our last
						### load time, loading any we find.
						Find.find( cmdsdir ) {|f|
							Find.prune if f =~ %r{^\.} # Ignore hidden stuff

							if f =~ %r{\.rb$} && File.stat( f ).file? && File.stat( f ).mtime > oldLoadTime
								load( f ) 
							end
						}
					}
				end


				### (CLASS) METHOD: buildCommandRegistry( config=MUES::Config )
				### Build the command registry after all the commands have a
				### chance to load
				def buildCommandRegistry( config )
					checkType( config, MUES::Config )
					
					@@CommandMutex.synchronize(Sync::EX) {
						return true if @@RegistryIsBuilt
						loadCommands( config )

						@@ChildClasses.each {|aSubClass|

							# Get the singleton instance of the command class
							cmd = aSubClass.instance

							# Build an array of command names
							names = [ cmd.name, cmd.synonyms ].flatten.compact

							### Test each name to make sure we aren't clobbering some
							### other command from another class. Warn to the log if
							### we're clobbering an old version of the command from the
							### same class.
							names.each {|name|
								if @@CommandRegistry.key?( name ) && @@CommandRegistry[name].class != aSubClass
									raise CommandNameConflictError,
										"Command '%s' has clashing implementations in %s and %s " % [
										name,
										@@CommandRegistry[name].class.name,
										aSubClass.name
									]
								elsif @@CommandRegistry.key?( name )
									$stderr.puts( "Redefining command '#{name}' from #{aSubClass.name}." )
								end

								# Install the command into the command registry
								@@CommandRegistry[ name ] = cmd
							}
						}
					}

					return true
				end


				### (CLASS) METHOD: rebuildCommandRegistry( config=MUES::Config )
				### Rebuild the command registry after checking for updates
				def rebuildCommandRegistry( config )
					@@CommandMutex.synchronize( Sync::EX ) {
						@@RegistryIsBuilt = false
						buildCommandRegistry( config )
					}
				end


				### (CLASS) METHOD: getCommands()
				### Returns a list of all loaded command objects
				def getCommands
					@@CommandRegistry.values.uniq
				end


				### (CLASS) METHOD: getPermissableCommands( aUser )
				### Returns the command objects that are permitted to the given
				### user.
				def getPermissableCommands( aUser )
					getCommands().find_all {|c| c.canBeUsedBy?(aUser)}
				end

			end # class << self

			
			### Public methods
			public

			### Abstract and accessor methods 
			abstract	:invoke
			attr_reader	:name, :synonyms, :description

			### METHOD: canBeUsedBy?( aUser=MUES::User )
			### Returns true if the command can be used by the user
			### specified. Returns false by default, so subclasses must supply
			### an explicit override for this method if it is to be usable.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return false
			end

			### METHOD: usage()
			### Return a usage string for the command
			def usage
				if @usage
					return "Usage: @usage"
				else
					return "Usage: @name <args>"
				end
			end

		end # class Command



		#############################################################
		###	A B S T R A C T   C O M M A N D   S U B C L A S S E S
		#############################################################

		### User command base class
		class UserCommand < Command

			### METHOD: canBeUsedBy?( aUser=MUES::User )
			### User commands can always be used, so this method just returns
			### true unconditionally.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return true
			end
		
			### (CLASS) METHOD: inherited( aSubClass )
			### Register the specified class with the list of child classes
			def UserCommand.inherited( aSubClass )
				@@ChildClasses |= [ aSubClass ]
			end

		end # class UserCommand


		### Creator command base class
		class CreatorCommand < Command

			### METHOD: canBeUsedBy?( aUser=MUES::User )
			### Returns true if the specified user has 'creator' or higher
			### permissions.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return aUser.isCreator?
			end
		
			### (CLASS) METHOD: inherited( aSubClass )
			### Register the specified class with the list of child classes
			def CreatorCommand.inherited( aSubClass )
				@@ChildClasses |= [ aSubClass ]
			end

		end # class CreatorCommand


		### Implementor command base class
		class ImplementorCommand < Command

			### METHOD: canBeUsedBy?( aUser=MUES::User )
			### Returns true if the specified user has 'implementor' or higher
			### permissions.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return aUser.isImplementor?
			end
		
			### (CLASS) METHOD: inherited( aSubClass )
			### Register the specified class with the list of child classes
			def ImplementorCommand.inherited( aSubClass )
				@@ChildClasses |= [ aSubClass ]
			end

		end # class ImplementorCommand


		### Admin command base class 
		class AdminCommand < Command

			### METHOD: canBeUsedBy?( aUser=MUES::User )
			### Returns true if the specified user has 'admin' or higher
			### permissions.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return aUser.isAdmin?
			end

			### (CLASS) METHOD: inherited( aSubClass )
			### Register the specified class with the list of child classes
			def AdminCommand.inherited( aSubClass )
				@@ChildClasses |= [ aSubClass ]
			end

		end # class AdminCommand


		#############################################################
		###	D E F A U L T   B A R E B O N E S   C O M M A N D S  
		#############################################################

		### Quit command
		class QuitCommand < UserCommand

			### METHOD: initialize()
			### Initialize a new QuitCommand object
			def initialize
				@name				= 'quit'
				@synonyms			= %w{logout}
				@description		= 'Disconnect from the server.'
				@usage				= 'quit'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the quit command, which generates a new UserLogoutEvent.
			def invoke( context, args )
				return MUES::UserLogoutEvent.new( context.user )
			end
		end # class QuitCommand


		### Quit command
		class HelpCommand < UserCommand

			### METHOD: initialize()
			### Initialize a new QuitCommand object
			def initialize
				@name				= 'help'
				@synonyms			= %w{}
				@description		= 'Fetch help about a command or all commands.'
				@usage				= 'help [<command>]'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the quit command, which generates a new UserLogoutEvent.
			def invoke( context, args )

				helpTable = nil
				rows = []

				### Fetch the help table from the shell's command table
				if args =~ %r{(\w+)}
					helpTable = context.shell.commandTable.getHelpTable( $1 )

					# If there was no help available, just output a message to
					# that effect
					return OutputEvent.new( "No help found for '$1'" ) if helpTable.nil?

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
			end
		end # class QuitCommand


		### 'Play' command
		class PlayCommand < UserCommand

			### METHOD: initialize()
			### Initialize a new PlayCommand object
			def initialize
				@name				= 'play'
				@synonyms			= %w{}
				@description		= 'Connect to the specified environment in the specified role.'
				@usage				= 'play <environment> <role>'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Attempt to connect the user to the environment and role
			### specified by the arguments.
			def invoke( context, args )
				results = []
				if args =~ %r{(\w+)\s+(\w+)}
					envName, roleName = $1, $2

					### Look for the requested role in the requested
					### environment, returning the new filter object if we find
					### it. Catch any problems as exceptions, and turn them into
					### error messages for output.
					begin
						env = engine().getEnvironment( envName ) or
							raise CommandError "No such environment '#{envName}'."
						role = env.getAvailableRoles( context.user ).find {|role|
							role.name == roleName
						}
						raise CommandError "Role '#{roleName}' is not currently available to you." unless
							role.is_a?( MUES::Role )

						results << env.getParticipantProxy( context.user, role )
					rescue CommandError, SecurityViolation => e
						results << OutputEvent.new( e.message )
					end
				else
					results << OutputEvent.new( usage() )
				end

				return results.flatten
			end
		end # class PlayCommand


		### 'Debug' command
		class DebugCommand < ImplementorCommand

			### METHOD: initialize()
			### Initialize a new DebugCommand object
			def initialize
				@name				= 'debug'
				@synonyms			= %w{}
				@description		= 'Set command shell debug level.'
				@usage				= 'debug [<level>]'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the debug command
			def invoke( context, args )
				if args =~ /=\s*(\d)/
					level = $1
					context.shell.debugLevel = level.to_i
					return OutputEvent.new( "Setting shell debug level to #{level}.\n" )

				else
					return OutputEvent.new( "Shell debug level is currently #{context.shell.debugLevel}.\n" )
				end
			end

		end # class DebugCommand

		
		### 'Eval' command
		class EvalCommand < AdminCommand

			### METHOD: initialize()
			### Initialize a new EvalCommand object
			def initialize
				@name				= 'eval'
				@synonyms			= %w{}
				@description		= 'Evaluate the specified ruby code in the current object context.'
				@usage				= 'eval <code>'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Evaluate the specified code in the shell's current object
			### context. This obviously is a dangerous command.
			def invoke( context, args )
				contextObject = context.evalContext

				rval = nil
				begin
					res = contextObject.instance_eval( args.strip, '<shell input>', 1 )
					rval = "=> #{res.inspect}\n\n"
				rescue StandardError, ScriptError => e
					rval = ">>> Eval error: #{e.to_s}\n\n"
				end
				
				return MUES::OutputEvent.new( rval )
			end
		end # class EvalCommand


		### 'Set' command
		class SetCommand < UserCommand

			### METHOD: initialize()
			### Initialize a new SetCommand object
			def initialize
				@name				= 'set'
				@synonyms			= %w{}
				@description		= 'Set shell parameters.'
				@usage				= 'set [<param> [= <value>]]'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=Hash )
			### Invoke the set command with either no args, a parameter name
			### arg, or parameter name + new value args.
			def invoke( context, args )
				results = []

				case args

				### <param> = <value> form (set)
				when /(\w+)\s*=\s*(.*)/

					param = $1
					value = $2

					# Strip enclosing quotes from the value
					_debugMsg 4, "Stripping quotes."
					value.gsub!( /\s*(["'])((?:[^\1]+|\\.)*)\1/ ) {|str| $2 }
					_debugMsg 4, "Done stripping."
					
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
			end # method invoke
		end # class SetCommand

	end # class CommandShell
end # module MUES


