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
# $Id: service.rb,v 1.6 2002/06/04 07:04:55 deveiant Exp $
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

require "singleton"

require "mues"
require "mues/Exceptions"
require "mues/Events"

module MUES

	### Abstract base class for MUES::Engine subsystems (services)
	class Service < MUES::Object ; implements MUES::Notifiable, MUES::AbstractClass, MUES::Event::Handler

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: service.rb,v 1.6 2002/06/04 07:04:55 deveiant Exp $

		# Directory to look for services (relative to $LOAD_PATH)
		ServicesDir = 'mues/services'

		# Instances of services, keyed by type
		@@instances = {}

		# Registered service classes, keyed by class name and shortened class
		# name
		@@registeredServices = {}


		### Initialize a new service object with the specified +name+ and
		### +description+. This method should be called via <tt>super()</tt> in
		### a derivative's initializer.
		def initialize( name, description )
			@name = name
			@description = description
		end


		### Class methods
		class << self

			### Register a Service as available
			def inherit( subClass )
				truncatedName = subClass.name.sub( /(?:.*::)?(\w+)(?:Service)?/, "\1" )
				@@registeredServices[ subClass.name ] = subClass
				@@registeredServices[ truncatedName ] = subClass
			end

			### Factory method: Instantiate and return a new Service of the
			### specified <tt>serviceClass</tt>, using the specified
			### <tt>objectStore</tt>, <tt>name</tt>, <tt>dump_undump</tt>
			### Proc, and <tt>indexes</tt> Array.
			def create( serviceClass, objectStore, name, dump_undump, indexes )
				unless @@registeredServices.has_key? serviceClass
					self.loadService( serviceClass )
				end

				@@registeredServices[ serviceClass ].new( objectStore,
														 name,
														 dump_undump,
														 indexes )
			end

			### Attempt to guess the name of the file containing the
			### specified service class, and look for it. If it exists, and
			### is not yet loaded, load it.
			def loadService( className )
				modName = File.join( ServicesDir,
									className.sub(/(?:.*::)?(\w+)(?:Service)?/, "\1Service") )

				# Try to require the module that defines the specified
				# service, raising an error if the require fails.
				unless require( modName )
					raise ObjectStoreError, "No such service class '#{className}'"
				end

				# Check to see if the specified service is now loaded. If it
				# is not, raise an error to that effect.
				unless @@registeredServices.has_key? className
					raise ObjectStoreError,
						"Loading '#{modName}' didn't define a service named '#{className}'"
				end

				return true
			end


			### Setup callback method
			def atEngineStartup( theEngine )
			end

			### Shutdown callback method
			def atEngineShutdown( theEngine )
			end
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

