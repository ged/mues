#!/usr/bin/ruby
#
# This file is a collection of classes which are used in the MUES command
# shell. The command shell is a command interface for user interaction with the
# MUES::Engine. This file contains the following classes:
#
# [MUES::CommandShell]
#   The main command shell class; it is a derivative of MUES::IOEventFilter.
#
# [MUES::CommandShell::Context]
#	A shell context class that is used by the shell to maintain command
#	invocation context.
#
# [MUES::CommandShell::CommandTable]
#	A command table for looking up command objects by name, synonym, or
#	abbreviation.
#
# [MUES::CommandShell::UserCommand]
#	The abstract base class for all user commands.
#
# [MUES::ShellCommand::CreatorCommand]
#	The abstract base class for all creator commands.
#
# [MUES::CommandShell::ImplementorCommand]
#	The abstract base class for all implementor commands.
#
# [MUES::CommandShell::AdminCommand]
#	The abstract base class for all admin commands.
#
# [MUES::CommandShell::HelpCommand]
# 	The <tt>help</tt> command.
#
# [MUES::CommandShell::RolesCommand]
# 	The <tt>roles</tt> command.
#
# [MUES::CommandShell::ConnectCommand]
# 	The <tt>connect</tt> command.
#
# [MUES::CommandShell::DisconnectCommand]
# 	The <tt>disconnect</tt> command.
#
# [MUES::CommandShell::DebugCommand]
# 	The <tt>debug</tt> command.
#
# [MUES::CommandShell::EvalCommand]
# 	The <tt>eval</tt> command.
#
# [MUES::CommandShell::SetCommand]
# 	The <tt>set</tt> command.
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
# $Id: commandshell.rb,v 1.12 2002/06/04 07:08:54 deveiant Exp $
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

require "mues"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

module MUES

	### Exception class for command name conflicts
	def_exception :CommandNameConflictError, "Command name conflict", Exception

	### This class is a MUES::IOEventFilter that provides connected users
	### with the ability to execute commands in the context of their
	### MUES::User object.
	class CommandShell < IOEventFilter ; implements MUES::Debuggable

		include MUES::ServerFunctions

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.12 $ )[1]
		Rcsid = %q$Id: commandshell.rb,v 1.12 2002/06/04 07:08:54 deveiant Exp $
		DefaultSortPosition = 700

		### Class attributes
		@@DefaultCommandString	= '/'
		@@DefaultPrompt			= 'mues> '
		@@Instances				= 0

		# A finalizer proc to unschedule the ReloadCommandsEvent if there aren't
		# any more instances.
		@@Finalizer = Proc.new {
			@@Instances -= 1
			_debugMsg( 2, "Decremented command shell instance count: #{@@Instances}" )
		}


		### Return a new shell input filter for the specified user (a MUES::User
		### object).
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


		######
		public
		######

		# The Hash of shell variables currently set in the shell
		attr_accessor	:vars

		# The string which will be prepended to all shell commands
		attr_accessor	:commandString

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
			@context = Context.new( self, @user, stream, nil )
			queueOutputEvents( OutputEvent.new(@vars['prompt']) )
			_debugMsg( 2, "Starting command shell for #{@user.to_s}" )
		end


		### Stop the filter for the specified stream (a MUES::IOEventStream
		### object).
		def stop( stream )
			@stream = nil
			@context = nil
			_debugMsg( 2, "Stopping command shell for #{@user.to_s}" )
			super( stream )
		end


		### Handle the specified input events by comparing them to the list of
		### valid shell commands and creating the appropriate events for any
		### that match.
		def handleInputEvents( *events )
			unhandledInputEvents = []

			_debugMsg( 5, "CommandShell: Got #{events.size} input events to filter." )

			### :TODO: This is probably only good for a few commands.
			### Eventually, this will probably become a dispatch table which
			### gets shell commands dynamically from somewhere.
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
				_debugMsg( 2, "Initializing context object for #{@user.to_s}" )
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

			include MUES::TypeCheckFunctions

			### Instantiate and return a new <tt>CommandTable</tt> object which
			### contains an abbreviation mapping for the specified
			### <tt>commandObjects</tt> (an Array of MUES::CommandShell::Command
			### objects).
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


		# This is an abstract base class for shell commands, which are
		# event-generating functions triggered by user input. They are loaded
		# the first time a MUES::CommandShell is created, and are kept up to
		# date by occasionally checking for updated files. Command objects are
		# Singletons.
		class Command < MUES::Object ; implements MUES::AbstractClass, MUES::Debuggable, Notifiable

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.12 $ )[1]
			Rcsid = %q$Id: commandshell.rb,v 1.12 2002/06/04 07:08:54 deveiant Exp $

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

				### Returns (after potentially creating) the instance of the
				### command class.
				def instance
					@@Instances[ self ] ||= new()
				end


				### Notification method (MUES::Notifiable interface) to register
				### update callback event after the engine is started.
				def atEngineStartup( theEngine )
					buildCommandRegistry( theEngine.config )
					@@ReloadEvent = CallbackEvent.new( self.method('rebuildCommandRegistry'), theEngine.config )
					theEngine.scheduleEvents( @@ReloadInterval, @@ReloadEvent )
					LogEvent.new( "notice", "Command registry built and rebuild event scheduled" );
				end


				### Notification method (MUES::Notifiable interface) to un-register
				### update callback event when the engine is about to shut down.
				def atEngineShutdown( theEngine )
					theEngine.cancelScheduledEvents( @@ReloadEvent )
					LogEvent.new( "notice", "Command registry rebuild event unscheduled" );
				end


				### Iterate over each file in the shell commands directory
				### specified by the given MUES::Config object, loading each one
				### if it's changed since last we loaded.
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


				### Build the command registry based on the specified
				### <tt>config</tt> (a MUES::Config object).
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


				### Rebuild the command registry after checking for
				### updates. Uses the specified <tt>config</tt> object to
				### determine what directories to load commands from.
				def rebuildCommandRegistry( config )
					_debugMsg( 2, "Rebuilding command registry at #{Time.now}" )
					@@CommandMutex.synchronize( Sync::EX ) {
						@@RegistryIsBuilt = false
						buildCommandRegistry( config )
					}
				end


				### Returns an Array of all loaded command objects
				def getCommands
					@@CommandRegistry.values.uniq
				end


				### Returns the command objects that are available to the given
				### user based on her user account type.
				def getPermissableCommands( aUser )
					getCommands().find_all {|c| c.canBeUsedBy?(aUser)}
				end


				### Register the specified class with the list of child classes
				### (callback).
				def inherited( aSubClass )
					@@ChildClasses |= [ aSubClass ]
				end

			end # class << self

			
			######
			public
			######

			### Abstract and accessor methods 

			# Invoke the command. This is a virtual method which must be
			# overridden in derivative classes.
			abstract	:invoke

			# The name by which the command is invoked
			attr_reader	:name

			# A (potentially empty) Array of synonyms for the command. 
			attr_reader :synonyms

			# The description of the command.
			attr_reader :description


			### Returns true if the command can be used by the user specified (a
			### MUES::User object). Returns false by default, so subclasses must
			### supply an explicit override for this method if it is to be
			### usable.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return false
			end


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

		### User command abstract base class (a derivative of
		### MUES::CommandShell::Command).
		class UserCommand < Command

			# Remove ourselves from the concrete classes list
			@@ChildClasses -= [ self ]

			### User commands can always be used, so this method just returns
			### true unconditionally.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return true
			end
		
		end # class UserCommand


		### Creator command base class (a derivative of
		### MUES::CommandShell::Command).
		class CreatorCommand < Command

			# Remove ourselves from the concrete classes list
			@@ChildClasses -= [ self ]

			### Returns true if the specified user has 'creator' or higher
			### permissions.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return aUser.isCreator?
			end
		
		end # class CreatorCommand


		### Implementor command base class (a derivative of
		### MUES::CommandShell::Command).
		class ImplementorCommand < Command

			# Remove ourselves from the concrete classes list
			@@ChildClasses -= [ self ]

			### Returns true if the specified user has 'implementor' or higher
			### permissions.
			def canBeUsedBy?( aUser )
				checkType( aUser, MUES::User )
				return aUser.isImplementor?
			end
		
		end # class ImplementorCommand


		### Admin command base class (a derivative of
		### MUES::CommandShell::Command).
		class AdminCommand < Command

			# Remove ourselves from the concrete classes list
			@@ChildClasses -= [ self ]

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

			def initialize # :nodoc:
				@name				= 'quit'
				@synonyms			= %w{logout}
				@description		= 'Disconnect from the server.'
				@usage				= 'quit'

				super
			end

			### Invoke the quit command, which generates a new
			### MUES::UserLogoutEvent.
			def invoke( context, args )
				return [ MUES::UserSaveEvent.new( context.user ), MUES::UserLogoutEvent.new( context.user ) ]
			end
		end # class QuitCommand


		### Help command
		class HelpCommand < UserCommand

			### Initialize a new HelpCommand object
			def initialize # :nodoc:
				@name				= 'help'
				@synonyms			= %w{}
				@description		= 'Fetch help about a command or all commands.'
				@usage				= 'help [<command>]'

				super
			end

			### Invoke the help command, which generates help documentation for
			### the specified command, or presents a table of all available
			### commands if no command is specified.
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

			include MUES::ServerFunctions

			### Initialize a new UnloadEnvironmentCommand object
			def initialize # :nodoc:
				@name			= 'roles'
				@synonyms		= %w{}
				@description	= 'List available roles in the specified environments.'
				@usage			= 'roles [<environment names>]'

				super
			end

			### Invoke the unload command, which generates a
			### UnloadEnvironmentEvent with the environment specified.
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

			### Initialize a new ConnectCommand object
			def initialize # :nodoc:
				@name				= 'connect'
				@synonyms			= %w{play}
				@description		= 'Connect to the specified environment in the specified role.'
				@usage				= 'connect [to] <environment> [as] <role>'

				super
			end

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

			### Initialize a new DisconnectCommand object
			def initialize # :nodoc:
				@name				= 'disconnect'
				@synonyms			= %w{}
				@description		= 'Disconnect from the specified role in the specified environment.'
				@usage				= 'disconnect [<role> [in]] <environment>'

				super
			end

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

			### Initialize a new DebugCommand object
			def initialize # :nodoc:
				@name				= 'debug'
				@synonyms			= %w{}
				@description		= 'Set command shell debug level.'
				@usage				= 'debug [<level>]'

				super
			end

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

			### Initialize a new EvalCommand object
			def initialize # :nodoc:
				@name				= 'eval'
				@synonyms			= %w{}
				@description		= 'Evaluate the specified ruby code in the current object context.'
				@usage				= 'eval <code>'

				super
			end

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

			### Initialize a new SetCommand object
			def initialize # :nodoc:
				@name				= 'set'
				@synonyms			= %w{}
				@description		= 'Set shell parameters.'
				@usage				= 'set [<param> [= <value>]]'

				super
			end

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
