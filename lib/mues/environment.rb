#!/usr/bin/ruby
#################################################################
=begin

=Environment.rb
== Name

Environment - MUES Environment object class

== Synopsis

  require "mues/Environment"

  environment = MUES::Environment.new
  environment.name = "Faerith"

  roles = environment.getAvailableRoles( aUser )
  participantObj = environment.connect( aUser, roles[0] )
  
== Description

This is an abstract base class for MUES environment objects.

== Classes

=== MUES::Environment
==== Class Methods

--- MUES::Environment.atEngineShutdown( theEngine )

    Clean up subsystems before engine shutdown

--- MUES::Environment.atEngineStartup( theEngine )

    Initialize subsystems after engine startup

--- MUES::Environment.create( concreteClassName )

    Load and instantiate the class specified by concreteClassName
    and return it

--- MUES::Environment.inherited( aSubClass )

    Register the specified class with the list of child classes

--- MUES::Environment.listEnvClasses()

    Return an array of environment classes which have been loaded

--- MUES::Environment.loadEnvClasses( config=MUES::Config )

    Iterate over each file in the environments directory, loading
    each one if it^s changed since last we loaded

==== Public Method

--- MUES::Environment#name

    Return the name of the environment.

--- MUES::Environment#description

    Return the environment description.

==== Protected Methods

--- MUES::Environment#initialize( aName, aDescription )

    Initialize an environment object with the specified name and description

==== Abstract Methods

--- MUES::Environment#getAvailableRoles( aUser )

    Returns an Array of MUES::Role objects that are available to the specified
    user.

--- MUES::Environment#getParticipantProxy( aUser, aRole )

	Connect the specified user to the environment in the specified role and
	return a MUES::ParticipantProxy object if the connection is successful, or
	raise a EnvironmentConnectFailed exception with an explanatory message
	describing the failure if the connection could not be established.

--- MUES::Environment#start

    Start the environment instance.

--- MUES::Environment#stop

    Stop the environment instance.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "sync"

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Events"
require "mues/Role"

module MUES
	
	### Exception class
	def_exception :EnvironmentNameConflictError, "Environment name conflict error", Exception

	### Environment abstract base class
	class Environment < Object ; implements AbstractClass, Notifiable, Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.8 $ )[1]
		Rcsid = %q$Id: environment.rb,v 1.8 2001/11/01 17:03:26 deveiant Exp $

		### Class variables
		@@ChildClasses = {}
		@@EnvMutex = Sync.new
		@@EnvLoadTime = Time.at(0) # Set initial load time to epoch

		### Class methods
		class << self

			### (CLASS) METHOD: loadEnvClasses( config=MUES::Config )
			### Iterate over each file in the environments directory, loading
			### each one if it's changed since last we loaded
			def loadEnvClasses( config )
				checkType( config, MUES::Config )
				envdir = config["Environments"]["EnvironmentsDir"] or
					raise Exception "No environments directory configured!"
				if envdir !~ %r{^/}
					debugMsg( 2, "Prepending rootdir '#{config['rootdir']}' to environments directory." )
					envdir = File.join( config['rootdir'], envdir )
				end

				### Load all ruby source in the configured directory newer
				### than our last load time. Each child will be registered
				### in the @@ChildClasses array as it's loaded (assuming
				### it's implemented correctly -- if it isn't, we don't much
				### care).
				@@EnvMutex.synchronize( Sync::EX ) {

					# Get the old load time for comparison and set it to the
					# current time
					oldLoadTime = @@EnvLoadTime
					@@EnvLoadTime = Time.now
					
					### Search top-down for ruby files newer than our last
					### load time, loading any we find.
					Find.find( envdir ) {|f|
						Find.prune if f =~ %r{^\.} # Ignore hidden stuff

						if f =~ %r{\.rb$} && File.stat( f ).file? && File.stat( f ).mtime > oldLoadTime
							load( f ) 
						end
					}
				}
			end

			### (CLASS) METHOD: listEnvClasses()
			### Return an array of environment classes which have been loaded
			def listEnvClasses
				return @@ChildClasses.keys.sort
			end

			### (CLASS) METHOD: create( concreteClassName )
			### Load and instantiate the class specified by concreteClassName
			### and return it
			def create( className )
				checkType( className, ::String )

				env = nil
				@@EnvMutex.synchronize( Sync::SH ) {
					if @@ChildClasses.has_key?( className )
						env = @@ChildClasses[ className ].new
					elsif @@ChildClasses.has_key?( "MUES::#{className}" )
						env = @@ChildClasses[ "MUES::#{className}" ].new
					else
						raise EnvironmentLoadError, "The '#{className}' environment class is not loaded."
					end
				}

				return env
			end

			### (CLASS) METHOD: atEngineStartup( theEngine )
			### Initialize subsystems after engine startup
			def atEngineStartup( theEngine )
			end

			### (CLASS) METHOD: atEngineShutdown( theEngine )
			### Clean up subsystems before engine shutdown
			def atEngineShutdown( theEngine )
			end

			### (CLASS) METHOD: inherited( aSubClass )
			### Register the specified class with the list of child classes
			def inherited( aSubClass )
				checkType( aSubClass, ::Class )
				@@ChildClasses[ aSubClass.name ] = aSubClass
			end
		end


		#############################################################
		###	P R O T E C T E D   M E T H O D S
		#############################################################
		protected

		### (PROTECTED) METHOD: initialize( aName, aDescription )
		### Initialize an environment object with the specified name and description
		def initialize( aName, aDescription )
			checkType( aName, ::String )
			checkType( aDescription, ::String )

			@name			= aName
			@description	= aDescription

			super()
		end


		#############################################################
		###	P U B L I C   M E T H O D S
		#############################################################
		public

		### Accessors
		attr_reader :name, :description
		abstract	:getParticipantProxy, :getAvailableRoles, :start, :stop

	end # class Environment
end # module MUES


