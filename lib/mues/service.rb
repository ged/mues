#!/usr/bin/ruby
# 
# This is an abstract base class for MUES services. A service is a subsystem
# which provides some auxilliary functionality to the hosted environments or
# other subsystems.
# 
# To implement a new service:
# 
# * Encapsulate the functions you want to offer in a class that inherits from
# 	the MUES::Service class.
# 
# * Add your class to the mues/lib/services directory, or require it explicitly
#   from somewhere.
# 
# * Add the events you want to use for interacting with your service either to
#   mues/events/ServiceEvents.rb, or define them in a separate class and add the
#   file to the list of requires to mues/Events.rb.
# 
# == Synopsis
# 
#   require "mues"
#   require "mues/Service"
#   require "mues/Events"
#   require "somethingElse"
# 
#   module MUES
#     class MyService < Service ; implements Notifiable
# 
# 	  def initialize
# 		registerHandlerForEvents( MyServiceEvent )
# 	  end
# 
#     end # class MyService
#   end # module MUES
#
# == Rcsid
# 
# $Id: service.rb,v 1.7 2002/07/09 14:56:13 deveiant Exp $
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

require "mues"
require "mues/Exceptions"
require "mues/Events"

module MUES

	### Service exception class
	def_exception :ServiceError, "Service Error", MUES::Exception


	### Abstract base class for MUES::Engine subsystems (services)
	class Service < MUES::Object ; implements MUES::Notifiable, MUES::AbstractClass

		include MUES::Event::Handler, MUES::FactoryMethods

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
		Rcsid = %q$Id: service.rb,v 1.7 2002/07/09 14:56:13 deveiant Exp $


		### Initialize a new service object with the specified +name+ and
		### +description+. This method should be called via <tt>super()</tt> in
		### a derivative's initializer.
		def initialize( name, description )
			@name = name
			@description = description
		end


		### Class methods

		### Directory to look for services, relative to $LOAD_PATH (part of
		### MUES::FactoryMethods interface)
		def self.derivativeDir
			return 'mues/services'
		end

		### Setup callback method
		def self.atEngineStartup( theEngine )
		end

		### Shutdown callback method
		def self.atEngineShutdown( theEngine )
		end


		######
		public
		######

		# The name of the service
		attr_reader :name

		# The description of the service
		attr_reader :description


	end # class Service
end # module MUES

