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

Things which a environment must offer:

--- getAvailableRoles( aUser )

    Returns an Array of MUES::Role objects that are available to the specified
    user.

--- getParticipantProxy( aUser, aRole )

	Connect the specified user to the environment in the specified role and
	return a MUES::ParticipantProxy object if the connection is successful, or
	raise a EnvironmentConnectFailed exception with an explanatory message
	describing the failure if the connection could not be established.

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
	class Environment < Object ; implements AbstractClass, Notifiable

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: environment.rb,v 1.6 2001/08/05 05:44:49 deveiant Exp $

		### Class methods
		class << self

			### METHOD: atEngineStartup( theEngine )
			### Initialize subsystems after engine startup
			def atEngineStartup( theEngine )
			end

			### METHOD: atEngineShutdown( theEngine )
			### Clean up subsystems before engine shutdown
			def atEngineShutdown( theEngine )
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


