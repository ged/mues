#!/usr/bin/ruby
#################################################################
=begin

=Service.rb

== Name

Service - Abstract base class for MUES subsystems (services)

== Synopsis

  require "mues/Namespace"
  require "mues/Service"
  require "mues/Events"
  require "somethingElse"

  module MUES
    class MyService < Service ; implements Notifiable

	  def initialize
		registerHandlerForEvents( MyServiceEvent )
	  end

    end # class MyService
  end # module MUES

== Description

This is an abstract base class for MUES services. A service is a subsystem which
provides some functionality to the hosted worlds or other subsystems through
(({ServiceEvent}))s.

 To implement a new service:

  - Encapsulate the functions you want to offer in a class that inherits from
	the MUES::Service class.

  - Add your class to the Services config section.

  - Add the events you want to use for interacting with your service either to
    mues/events/ServiceEvents.rb, or define them in a separate class and add the
    file to the list of requires to mues/Events.rb.

== Classes
=== MUES::Service
==== Factory Methods

--- MUES::Service.getService( name )

	Get the service specified by the given name, instantiating it if necessary.

==== Class Methods

--- MUES::Service.atEngineStartup( engine )

    ((<MUES::Notifiable|Notifiable>)) interface method.

--- MUES::Service.atEngineShutdown( engine )

    ((<MUES::Notifiable|Notifiable>)) interface method.

==== Public Methods

--- MUES::Service#name

    Return the name of the service.

--- MUES::Service#description

    Return the description of the service.

==== Protected Methods

--- MUES::Service#initialize( name, description )

    Setup and initialize a new service object with the specified ((|name|)) and
    ((|description|)).

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "singleton"

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Events"

module MUES
	class Service < Object ; implements MUES::Notifiable, AbstractClass

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: service.rb,v 1.3 2001/11/01 17:15:06 deveiant Exp $

		### Class methods
		class << self

			### (CLASS) METHOD: getService( name )
			### Get the service specified by the given ((|name|)), instantiating
			### it if necessary.
			def getService( type )
			end

			### (CLASS) METHOD: atEngineStartup( theEngine )
			### Setup method
			def atEngineStartup( theEngine )
			end

			### (CLASS) METHOD: atEngineShutdown( theEngine )
			### Shutdown methods
			def atEngineShutdown( theEngine )
			end
		end

		protected

		### (PROTECTED) METHOD: initialize( name )
		### Setup and initialize a new service object with the specified name.
		def initialize( name, description )
			@name = name
			@description = description
		end


		#############################################################
		###	P U B L I C   M E T H O D S
		#############################################################
		public

		attr_reader :name, :description

	end # class Service

end # module MUES

