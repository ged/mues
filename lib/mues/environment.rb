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
#	Start the environment running, returning any startup events which should be
#	dispatched.
#
# [<b><tt>stop()</tt></b>]
#	Stop/shut the environment down, returning any cleanup events which should be
#	dispatched.
#
# == Rcsid
# 
# $Id: environment.rb,v 1.12 2002/07/07 18:29:57 deveiant Exp $
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
	class Environment < Object ; implements MUES::AbstractClass,
			MUES::Notifiable, MUES::Debuggable

		include MUES::TypeCheckFunctions, MUES::Event::Handler, MUES::FactoryMethods

		### Class constants
		# Versioning stuff
		Version = /([\d\.]+)/.match( %q$Revision: 1.12 $ )[1]
		Rcsid = %q$Id: environment.rb,v 1.12 2002/07/07 18:29:57 deveiant Exp $


		### Class globals
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

		### Return an array of environment class names which have been loaded
		def self.listEnvClasses
			return self.getDerivativeClasses.collect {|klass|
				klass.name.sub( /Environment/ )
			}
		end


		### Initialize subsystems after engine startup (stub).
		def self.atEngineStartup( theEngine )
		end


		### Clean up subsystems before engine shutdown (stub).
		def self.atEngineShutdown( theEngine )
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


