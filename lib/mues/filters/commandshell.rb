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
(({MUES::ShellCommand::AdminCommand}))), as well as several concrete shell
command classes.

== Classes
=== MUES::CommandShell

This a ((<MUES::IOEventFilter>)) that provides connected users with the ability to
execute commands in the context of their ((<MUES::User>)) object.

==== Protected Methods

--- MUES::CommandShell#initialize( aUser )

    Initialize a new shell input filter for the specified user

==== Public Methods

--- MUES::CommandShell#handleInputEvents( *events )

    Handle input events by comparing them to the list of valid shell
    commands and creating the appropriate events for any that do.

--- MUES::CommandShell#start( aStream=MUES::IOEventStream )

    Start the filter .

--- MUES::CommandShell#stop( aStream=MUES::IOEventStream )

    Stop the filter.

=== MUES::CommandShell::Context

Instances of this class are state objects that are used in the shell object to
maintain command invocation context, and to provide access to external objects
to the command objects.

==== Public Methods

--- MUES::CommandShell::Context#shell

    Return the ((<MUES::CommandShell>)) object this context belongs to.

--- MUES::CommandShell::Context#user

    Return the ((<MUES::User>)) object of the current user.

--- MUES::CommandShell::Context#stream

    Return the ((<MUES::IOEventStream>)) object the command shell is running in.

--- MUES::CommandShell::Context#evalContext

    Returns the "current" context, which is an object upon which all shell
    commands which require a context operate. This can be used to provide a
    default target for commands, for example.

--- MUES::CommandShell::Context#evalContext=( anObject )

    Set the "current" context to ((|anObject|)).

--- MUES::CommandShell::Context#initialize( shell, user, stream, evalContext )

    Set up and initialize the command shell with the specified ((|shell|)),
    ((|user|)) object, ((|stream|)), and ((|evalContext|)) object.


=== MUES::CommandShell::CommandTable

Instances of this class contain a table of all commands and their aliases which
are available to a particular user, along with an abbrev-table which maps
abbreviated non-ambiguous versions of each command to the corresponding command
object. It also contains utility functions for generating command help text, and
for performing approximate searches of command names.

==== Public Methods

--- MUES::CommandShell::CommandTable#[ name ]

    Element reference operator -- Returns the command object which corresponds
	to the (potentially abbreviated) command name ((|name|)). Returns a
	((<MUES::CommandShell::Command>)) object if a corresponding one is found, or
	(({nil})) if no command corresponds to the given name.

--- MUES::CommandShell::CommandTable#approxSearch( name )

    Find and return all commands which match the specified ((|name|)).

--- MUES::CommandShell::CommandTable#getHelpTable( [commandName] )

    Returns a hash of commands to descriptions suitable for building
    a command help table

--- MUES::CommandShell::CommandTable#new( commandObjects=Array(MUES::CommandShell::Command) )

	Instantiate and return a new (({CommandTable})) object which contains an
	abbreviation mapping for the specified (({commandObjects})).

=== MUES::CommandShell::Command

This is an abstract base class for shell commands, which are functions triggered
by user input. They are loaded the first time a shell is created, and are kept
up to date by occasionally checking for updated files. Command objects are
((<Singletons>)).

==== Class Methods

--- MUES::CommandShell::Command.atEngineShutdown( theEngine=MUES::Engine )

    Notification method (((<MUES::Notifiable>)) interface) to un-register update
    callback event when the engine is about to shut down.

--- MUES::CommandShell::Command.atEngineStartup( theEngine=MUES::Engine )

    Notification method (((<MUES::Notifiable>)) interface) to register update
    callback event after the engine is started.

--- MUES::CommandShell::Command.buildCommandRegistry( config=MUES::Config )

    Build the command registry after all the commands have a chance to load.

--- MUES::CommandShell::Command.getCommands()

    Returns a list of all loaded (({MUES::CommandShell::Command})) objects.

--- MUES::CommandShell::Command.getPermissableCommands( aUser )

    Returns the (({MUES::CommandShell::Command})) objects that are permitted to
    ((|aUser|)).

--- MUES::CommandShell::Command.inherited( aSubClass )

    Register the specified class with the list of child classes.

--- MUES::CommandShell::Command.instance()

    Returns the singleton instance of the command class.

--- MUES::CommandShell::Command.loadCommands( config=MUES::Config )

    Iterate over each file in the shell commands directory, as specified by the
    ((|config|)) object, loading each one if it has changed since last we
    loaded.

--- MUES::CommandShell::Command.rebuildCommandRegistry( config=MUES::Config )

    Rebuild the command registry after checking for updates.

==== Public Methods

--- MUES::CommandShell::Command#canBeUsedBy?( aUser=MUES::User )

    Returns (({true})) if the command can be used by ((|aUser|)). Returns
    (({false})) by default, so subclasses must supply an explicit override for
    this method if it is to be usable.

--- MUES::CommandShell::Command#usage()

    Return a usage string for the command.

=== MUES::CommandShell::UserCommand

An abstract base class for commands usable by all Users.

==== Public Methods

--- MUES::CommandShell::UserCommand#canBeUsedBy?( aUser=MUES::User )

    User commands can always be used, so this method just returns
    true unconditionally.

=== MUES::CommandShell::CreatorCommand

An abstract base class for commands usable by Users who have 'creator'
privileges or higher.

==== Public Methods

--- MUES::CommandShell::CreatorCommand#canBeUsedBy?( aUser=MUES::User )

    Returns true if the specified user has 'creator' or higher
    permissions.

=== MUES::CommandShell::ImplementorCommand

An abstract base class for commands usable by Users who have 'implementor'
privileges or higher.

==== Public Methods

--- MUES::CommandShell::ImplementorCommand#canBeUsedBy?( aUser=MUES::User )

    Returns true if the specified user has 'implementor' or higher
    permissions.

=== MUES::CommandShell::AdminCommand

An abstract base class for commands usable by Users who have 'admin' privileges.

==== Public Methods

--- MUES::CommandShell::AdminCommand#canBeUsedBy?( aUser=MUES::User )

    Returns true if the specified user has 'admin' or higher
    permissions.

=== MUES::CommandShell::QuitCommand

The 'quit' command class.

==== Public Methods

--- MUES::CommandShell::QuitCommand#initialize()

    Initialize a new QuitCommand object

--- MUES::CommandShell::QuitCommand#invoke( context=MUES::CommandShell::Context, args=String )

    Invoke the quit command, which generates a new UserLogoutEvent.

=== MUES::CommandShell::HelpCommand

The 'help' command class.

==== Public Methods

--- MUES::CommandShell::HelpCommand#initialize()

    Initialize a new QuitCommand object

--- MUES::CommandShell::HelpCommand#invoke( context=MUES::CommandShell::Context, args=String )

    Invoke the quit command, which generates a new UserLogoutEvent.

=== MUES::CommandShell::RolesCommand

The 'roles' command class.

==== Public Methods

--- MUES::CommandShell::RolesCommand#initialize()

    Initialize a new UnloadEnvironmentCommand object

--- MUES::CommandShell::RolesCommand#invoke( context=MUES::CommandShell::Context, args=String )

    Invoke the unloadenvironment command, which generates a
    UnloadEnvironmentEvent with the environment specifications.

=== MUES::CommandShell::ConnectCommand

The 'connect' command class.

==== Public Methods

--- MUES::CommandShell::ConnectCommand#initialize()

    Initialize a new ConnectCommand object

--- MUES::CommandShell::ConnectCommand#invoke( context=MUES::CommandShell::Context, args=String )

    Attempt to connect the user to the environment and role specified by the
    arguments.

=== MUES::CommandShell::DisconnectCommand

The 'disconnect' command class.

==== Public Methods

--- MUES::CommandShell::DisconnectCommand#initialize()

    Initialize a new DisconnectCommand object

--- MUES::CommandShell::DisconnectCommand#invoke( context=MUES::CommandShell::Context, args=String )

    Attempt to disconnect the user from the environment and role specified by
    the arguments.

=== MUES::CommandShell::DebugCommand

The 'debug' command class.

==== Public Methods

--- MUES::CommandShell::DebugCommand#initialize()

    Initialize a new DebugCommand object

--- MUES::CommandShell::DebugCommand#invoke( context=MUES::CommandShell::Context, args=String )

    Invoke the debug command

=== MUES::CommandShell::EvalCommand

The 'eval' command class.

==== Public Methods

--- MUES::CommandShell::EvalCommand#initialize()

    Initialize a new EvalCommand object

--- MUES::CommandShell::EvalCommand#invoke( context=MUES::CommandShell::Context, args=String )

    Evaluate the specified code in the shell^s current object context. This
    is a potentially dangerous command.

=== MUES::CommandShell::SetCommand

The 'set' command class.

==== Public Methods

--- SetCommand#initialize()

    Initialize a new SetCommand object

--- SetCommand#invoke( context=MUES::CommandShell::Context, args=String )

    Invoke the set command with either no args, a parameter name arg, or
    parameter name + new value args.

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
		Version = /([\d\.]+)/.match( %q$Revision: 1.9 $ )[1]
		Rcsid = %q$Id: commandshell.rb,v 1.9 2001/11/01 17:42:05 deveiant Exp $
		DefaultSortPosition = 700

		### Class attributes
		@@DefaultCommandString	= '/'
		@@DefaultPrompt			= 'mues> '
		@@Instances				= 0

		# A finalizer proc to unschedule the ReloadCommandsEvent if there aren't
		# any more instances.
		@@Finalizer = Proc.new {
			@@Instances -= 1
			_debugMsg( 2, "Decremeted command shell instance count: #{@@Instances}" )
		}


		#############################################################
		###	P R O T E C T E D   M E T H O D S
		#############################################################

		### (PROTECTED) METHOD: initialize( aUser )
		### Initialize a new shell input filter for the specified user
		protected
		def initialize( aUser )
			super()
			_debugMsg( 1, "Initializing command shell for #{aUser.to_s}." )
			@user = aUser
			@commandString = @@DefaultCommandString
			@context = nil
			@vars = { 'prompt' => @@DefaultPrompt }

			@commandTable = CommandTable.new( Command.getPermissableCommands(aUser) )

			@stream = nil

			@@Instances += 1
			_debugMsg( 2, "Incremented command shell instance count: #{@@Instances}" )
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
			super( stream )
			@stream = stream
			@context = Context.new( self, @user, stream, nil )
			queueOutputEvents( OutputEvent.new(@vars['prompt']) )
			_debugMsg( 2, "Starting command shell for #{@user.to_s}" )
		end


		### METHOD: stop( aStream=MUES::IOEventStream )
		### Stop the filter.
		def stop( stream )
			@stream = nil
			@context = nil
			_debugMsg( 2, "Stopping command shell for #{@user.to_s}" )
			super( stream )
		end


		### METHOD: handleInputEvents( *events )
		### Handle input events by comparing them to the list of valid shell
		### commands and creating the appropriate events for any that do.
		def handleInputEvents( *events )
			unhandledInputEvents = []

			_debugMsg( 5, "CommandShell: Got #{events.size} input events to filter." )

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

		### CommandShell Context object class
		class Context < MUES::Object ; implements Debuggable
			attr_reader :shell, :user, :stream
			attr_accessor :evalContext
			def initialize( shell, user, stream, evalContext )
				@shell = shell
				@user = user
				@stream = stream
				@evalContext = evalContext
				_debugMsg( 2, "Initializing context object for #{@user.to_s}" )
				super()
			end
		end # class Context

		### CommandTable class
		class CommandTable < MUES::Object ; implements Debuggable

			### METHOD: new( commandObjects=Array(MUES::CommandShell::Command) )
			### Instantiate and return a new (({CommandTable})) object which
			### contains an abbreviation mapping for the specified
			### (({commandObjects})).
			def initialize( commands )
				checkType( commands, Array )

				_debugMsg( 2, "Initializing command table with #{commands.length} commands" )
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

				_debugMsg( 3, "CommandTable: Abbrev table has #{@abbrevTable.keys.length} unique keys." )
				super()
			end

			### METHOD: [ name ]
			### Element reference operator -- Returns the command object which
			### corresponds to the (potentially abbreviated) command name
			### ((|name|)). Returns a ((<MUES::CommandShell::Command>)) object
			### if a corresponding one is found, or (({nil})) if no command
			### corresponds to the given name.
			def []( name )
				return @abbrevTable[ name ]
			end

			### METHOD: approxSearch( name )
			### Find and return all commands which match the specified ((|name|)).
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
			Version = /([\d\.]+)/.match( %q$Revision: 1.9 $ )[1]
			Rcsid = %q$Id: commandshell.rb,v 1.9 2001/11/01 17:42:05 deveiant Exp $

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
					@@ReloadEvent = CallbackEvent.new( self.method('rebuildCommandRegistry'), theEngine.config )
					theEngine.scheduleEvents( @@ReloadInterval, @@ReloadEvent )
					LogEvent.new( "notice", "Command registry built and rebuild event scheduled" );
				end


				### (CLASS) METHOD: atEngineShutdown( theEngine=MUES::Engine )
				### Notification method (Notifiable interface) to un-register
				### update callback event when the engine is about to shut down.
				def atEngineShutdown( theEngine )
					theEngine.cancelScheduledEvents( @@ReloadEvent )
					LogEvent.new( "notice", "Command registry rebuild event unscheduled" );
				end


				### (CLASS) METHOD: loadCommands( config=MUES::Config )
				### Iterate over each file in the shell commands directory, loading
				### each one if it's changed since last we loaded
				def loadCommands( config )
					checkType( config, MUES::Config )
					cmdsdir = config["CommandShell"]["CommandsDir"] or
						raise Exception "No commands directory configured!"
					if cmdsdir !~ %r{^/}
						debugMsg( 2, "Prepending rootdir '#{config['rootdir']}' to commands directory." )
						cmdsdir = File.join( config['rootdir'], cmdsdir )
					end
					

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
					_debugMsg( 2, "Rebuilding command registry at #{Time.now}" )
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

				### (CLASS) METHOD: inherited( aSubClass )
				### Register the specified class with the list of child classes
				def inherited( aSubClass )
					@@ChildClasses |= [ aSubClass ]
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
					return "Usage: #{@usage}\n"
				else
					return "Usage: #{@name} <args>\n"
				end
			end

		end # class Command



		#############################################################
		###	A B S T R A C T   C O M M A N D   S U B C L A S S E S
		#############################################################

		### User command base class
		class UserCommand < Command

			# Remove ourselves from the concrete classes list
			@@ChildClasses -= [ self ]

			### METHOD: canBeUsedBy?( aUser=MUES::User )
			### User commands can always be used, so this method just returns
			### true unconditionally.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return true
			end
		
		end # class UserCommand


		### Creator command base class
		class CreatorCommand < Command

			# Remove ourselves from the concrete classes list
			@@ChildClasses -= [ self ]

			### METHOD: canBeUsedBy?( aUser=MUES::User )
			### Returns true if the specified user has 'creator' or higher
			### permissions.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return aUser.isCreator?
			end
		
		end # class CreatorCommand


		### Implementor command base class
		class ImplementorCommand < Command

			# Remove ourselves from the concrete classes list
			@@ChildClasses -= [ self ]

			### METHOD: canBeUsedBy?( aUser=MUES::User )
			### Returns true if the specified user has 'implementor' or higher
			### permissions.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return aUser.isImplementor?
			end
		
		end # class ImplementorCommand


		### Admin command base class 
		class AdminCommand < Command

			# Remove ourselves from the concrete classes list
			@@ChildClasses -= [ self ]

			### METHOD: canBeUsedBy?( aUser=MUES::User )
			### Returns true if the specified user has 'admin' or higher
			### permissions.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return aUser.isAdmin?
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

			### METHOD: invoke( context=MUES::CommandShell::Context, args=String )
			### Invoke the quit command, which generates a new UserLogoutEvent.
			def invoke( context, args )
				return [ MUES::UserSaveEvent.new( context.user ), MUES::UserLogoutEvent.new( context.user ) ]
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

			### METHOD: invoke( context=MUES::CommandShell::Context, args=String )
			### Invoke the quit command, which generates a new UserLogoutEvent.
			def invoke( context, args )

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
			end
		end # class QuitCommand


		### 'Roles' command
		class RolesCommand < UserCommand

			### METHOD: initialize()
			### Initialize a new UnloadEnvironmentCommand object
			def initialize
				@name			= 'roles'
				@synonyms		= %w{}
				@description	= 'List available roles in the specified environments.'
				@usage			= 'roles [<environment names>]'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=String )
			### Invoke the unloadenvironment command, which generates a
			### UnloadEnvironmentEvent with the environment specifications.
			def invoke( context, args )
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
			end
		end


		### 'Connect' command
		class ConnectCommand < UserCommand

			### METHOD: initialize()
			### Initialize a new ConnectCommand object
			def initialize
				@name				= 'connect'
				@synonyms			= %w{play}
				@description		= 'Connect to the specified environment in the specified role.'
				@usage				= 'connect [to] <environment> [as] <role>'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=String )
			### Attempt to connect the user to the environment and role
			### specified by the arguments.
			def invoke( context, args )
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
			end
		end # class ConnectCommand


		### 'Disconnect' command
		class DisconnectCommand < UserCommand

			### METHOD: initialize()
			### Initialize a new DisconnectCommand object
			def initialize
				@name				= 'disconnect'
				@synonyms			= %w{}
				@description		= 'Disconnect from the specified role in the specified environment.'
				@usage				= 'disconnect [<role> [in]] <environment>'

				super
			end

			### METHOD: invoke( context=MUES::CommandShell::Context, args=String )
			### Attempt to disconnect the user from the environment and role
			### specified by the arguments.
			def invoke( context, args )
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
			end
		end # class DisconnectCommand


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

			### METHOD: invoke( context=MUES::CommandShell::Context, args=String )
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

			### METHOD: invoke( context=MUES::CommandShell::Context, args=String )
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

			### METHOD: invoke( context=MUES::CommandShell::Context, args=String )
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
