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
#   # Create a new environment object
#   environment = MUES::Environment::new( "Faerith" )
#
#   # Get the list of roles available to the user
#   roles = environment.getAvailableRoles( aUser )
#
#   # After determining the desired role, get an IOEventFilter that can be
#   # inserted into the user's IOEventStream to allow interaction with the
#   # Environment and insert it.
#   proxy = environment.getParticipantProxy( aUser, roles[0] )
#   aUser.ioEventStream.addFilters( proxy )
#
#   
# == Contract
#
# Subclasses are required to provide implementations of the following methods:
#
# [<b><tt>start()</tt></b>]
#   Start the environment running, returning any startup events which should be
#   dispatched.
#
# [<b><tt>stop()</tt></b>]
#   Stop/shut the environment down, returning any cleanup events which should be
#   dispatched.
#
# If the default shell commands for interacting with environments
# (server/shellCommands/environments.cmd) are used, environments should also
# implement the following methods:
#
# [<b><tt>getParticipantProxy( <em>user</em>, <em>role</em> )</tt></b>]
#   Factory method; should instantate and return a MUES::ParticipantProxy object
#   (or an instance of one of its subclasses) for the specified <em>user</em>
#   and <em>role</em>. Should raise an exception of type MUES::EnvironmentError
#   (or a subclass) if the operation is not possible for some reason.
#
# [<b><tt>getAvailableRoles( <em>user</em> )</tt></b>]
#   Should return a list of MUES::Role objects which describe the roles for
#   participation available to the given <em>user</em>.
#
# Different modes of connection to an Environment can be created by modifying or
# replacing the commands for interacting with them.
#
# == Rcsid
# 
# $Id: environment.rb,v 1.19 2003/09/12 04:13:23 deveiant Exp $
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

require "mues/Object"
require "mues/Mixins"
require "mues/Exceptions"
require "mues/Events"
require "mues/Role"
require "mues/IOEventFilters"

module MUES

	### Environment abstract base class
	class Environment < MUES::Object ; implements MUES::AbstractClass,
			MUES::Notifiable, MUES::Debuggable

		include MUES::TypeCheckFunctions, MUES::Event::Handler, MUES::FactoryMethods

		### Class constants
		# Versioning stuff
		Version = /([\d\.]+)/.match( %q{$Revision: 1.19 $} )[1]
		Rcsid = %q$Id: environment.rb,v 1.19 2003/09/12 04:13:23 deveiant Exp $


		### Class variables and methods

		# The directories to search for derivative classes
		@derivativeDirs = []
		class << self
			attr_accessor :derivativeDirs
		end


		### Return an array of environment class names which have been loaded
		def self.listEnvClasses
			return self.derivativeClasses.collect {|klass|
				klass.name.sub( /Environment/, '' )
			}
		end

		### Initialize subsystems after engine startup (stub).
		def self.atEngineStartup( theEngine )
			[]
		end

		### Clean up subsystems before engine shutdown (stub).
		def self.atEngineShutdown( theEngine )
			[]
		end



		### Constructor

		### Initialize the environment with the specified <tt>name</tt> and
		### <tt>description</tt>.
		def initialize( name, description="(No description)", parameters={} ) # :notnew:
			checkType( name, ::String )
			checkType( description, ::String )
			checkType( parameters, ::Hash )

			@name			= name
			@description	= description
			@parameters		= parameters

			super()
		end


		######
		public
		######

		# The name of the environment object
		attr_reader :name

		# The user-readable description of the object
		attr_reader :description


		### Virtual methods
		abstract	:start, :stop

	end # class Environment
end # module MUES


