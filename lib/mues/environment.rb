#!/usr/bin/ruby
#
# This is an abstract base class for MUES environment objects. Environments are
# objects which contain the main context of interaction between Users and other
# objects, as well as the expression of the rules of that interaction. It is the
# Universe of Discourse in which the interaction takes place. In a game context,
# for example, the Environment contains the logic for all gameplay, including
# rules for movement about a space, class definitions for in-game objects, and a
# function library which can be used in the expression of those objects to
# interact with the containing server and the world itself.
# 
# == Synopsis
# 
#   require "mues/Environment"
# 
#   environment = MUES::Environment.new
#   environment.name = "Faerith"
# 
#   roles = environment.getAvailableRoles( aUser )
#   [...]
#   participantObj = environment.connect( aUser, roles[0] )
#   
# == Contract
#
# Subclasses are required to provide implementations of the following methods:
#
# [<b><tt>getParticipantProxy( <em>user</em>, <em>role</em> )</tt></b>]
#	Factory method; should instantate and return a MUES::ParticipantProxy object
#	(or an instance of one of its subclasses) for the specified <em>user</em>
#	and <em>role</em>. Should raise an exception of type MUES::EnvironmentError
#	(or a subclass) if the operation is not possible for some reason.
#
# [<b><tt>removeParticipantProxy( <em>proxy</em> )</tt></b>]
#	Should remove the specified <em>proxy</em> object from the environment's
#	list of participants, if it exists therein. Should return true on success,
#	false if the specified proxy was not listed as a participant in this
#	environment. Should raise an error of type MUES::EnvironmentError (or a
#	subclass) if the operation is not possible for some other reason.
#
# [<b><tt>start()</tt></b>]
#	Start the environment running.
#
# [<b><tt>stop()</tt></b>]
#	Stop/shut the environment down.
#
# == Rcsid
# 
# $Id: environment.rb,v 1.11 2002/06/04 06:58:40 deveiant Exp $
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

require "mues"
require "mues/Exceptions"
require "mues/Events"
require "mues/Role"
require "mues/IOEventFilters"

module MUES

	### Exception class used for indicating a problem in an environment object
	def_exception :EnvironmentError, "General environment error", Exception

	### Exception class used when an environment is created with the same name as
	### an already-extant one.
	def_exception :EnvironmentNameConflictError, "Environment name conflict error", EnvironmentError

	### Exception class used to indicate a problem with a role object in an environment.
	def_exception :EnvironmentRoleError, "Environment role error", EnvironmentError


	### Environment abstract base class
	class Environment < Object ; implements MUES::AbstractClass, MUES::Notifiable, MUES::Debuggable, MUES::Event::Handler

		include MUES::TypeCheckFunctions

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.11 $ )[1]
		Rcsid = %q$Id: environment.rb,v 1.11 2002/06/04 06:58:40 deveiant Exp $

		### Class variables
		@@ChildClasses = {}
		@@EnvMutex = Sync.new
		@@EnvLoadTime = Time.at(0) # Set initial load time to epoch


		### Initialize the environment with the specified <tt>name</tt> and
		### <tt>description</tt>.
		def initialize( aName, aDescription="(No description)" ) # :notnew:
			checkType( aName, ::String )
			checkType( aDescription, ::String )

			@name			= aName
			@description	= aDescription

			super()
		end


		### Class methods
		class << self

			### Iterate over each file in the environments directory specified by
			### +config+ (a MUES::Config object), loading each one if it's changed
			### since last we loaded.
			def loadEnvClasses( config )
				checkType( config, MUES::Config )
				envdir = config["Environments"]["EnvironmentsDir"] or
					raise Exception "No environments directory configured!"
				if envdir !~ %r{^/}
					debugMsg( 2, "Prepending rootdir '#{config['rootdir']}' to environments directory." )
					envdir = File.join( config['rootdir'], envdir )
				end

				# Load all ruby source in the configured directory newer
				# than our last load time. Each child will be registered
				# in the @@ChildClasses array as it's loaded (assuming
				# it's implemented correctly -- if it isn't, we don't much
				# care).
				@@EnvMutex.synchronize( Sync::EX ) {

					# Get the old load time for comparison and set it to the
					# current time
					oldLoadTime = @@EnvLoadTime
					@@EnvLoadTime = Time.now
					
					# Search top-down for ruby files newer than our last
					# load time, loading any we find.
					Find.find( envdir ) {|f|
						Find.prune if f =~ %r{^\.} # Ignore hidden stuff

						if f =~ %r{\.rb$} && File.stat( f ).file? && File.stat( f ).mtime > oldLoadTime
							load( f ) 
						end
					}
				}
			end


			### Return an array of environment classes which have been loaded
			def listEnvClasses
				return @@ChildClasses.keys.sort
			end


			### Load and instantiate the environment class specified by
			### <tt>className</tt>, assign the specified <tt>instanceName</tt>
			### to it, and return it.
			def create( className, instanceName )
				checkType( className, ::String )
				checkType( instanceName, ::String )

				env = nil
				@@EnvMutex.synchronize( Sync::SH ) {
					if @@ChildClasses.has_key?( className )
						env = @@ChildClasses[ className ].new( instanceName )
					elsif @@ChildClasses.has_key?( "MUES::#{className}" )
						env = @@ChildClasses[ "MUES::#{className}" ].new( instanceName )
					else
						raise EnvironmentLoadError, "The '#{className}' environment class is not loaded."
					end
				}

				return env
			end


			### Initialize subsystems after engine startup (stub).
			def atEngineStartup( theEngine )
			end


			### Clean up subsystems before engine shutdown (stub).
			def atEngineShutdown( theEngine )
			end


			### Register the specified class <tt>aSubClass</tt> with the list of
			### available child classes.
			def inherited( aSubClass )
				checkType( aSubClass, ::Class )
				@@ChildClasses[ aSubClass.name ] = aSubClass
			end
		end


		######
		public
		######

		# The name of the environment object
		attr_reader :name


		# The user-readable description of the object
		attr_reader :description


		### Virtual methods
		abstract	:getParticipantProxy, :getAvailableRoles, :start, :stop

	end # class Environment
end # module MUES


