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

== Methods
=== Factory Method

--- MUES::Service.getService( name )

	Get the service specified by the given name, instantiating it if necessary.

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
		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: service.rb,v 1.2 2001/08/05 05:46:08 deveiant Exp $

		### Class methods
		class << self

			### (CLASS) METHOD: getService( name )
			### Get the service specified by the given ((|name|)), instantiating
			### it if necessary.
			def getService( type )
				TestService.instance
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

		### (PROTECTED) METHOD: initialize()
		protected

		#############################################################
		###	P U B L I C   M E T H O D S
		#############################################################
		public

	end # class Service

	class TestService < Service; implements Singleton
	end

end # module MUES

