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
#   require 'mues/mixins'
#   require 'mues/service'
#   require 'mues/events'
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
# == Subversion ID
# 
# $Id$
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

require 'pluginfactory'

require 'mues/object'
require 'mues/exceptions'
require 'mues/events'

module MUES

	### Service exception class
	def_exception :ServiceError, "Service Error", MUES::Exception


	### Abstract base class for MUES::Engine subsystems (services)
	class Service < MUES::Object ; implements MUES::Notifiable, MUES::AbstractClass

		include MUES::Event::Handler, PluginFactory

		### Class constants

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		### Class globals
		@@ServiceDirectories = ["mues/services"]


		### Initializer

		### Initialize a new service object with the specified +name+ and
		### +description+. This method should be called via <tt>super()</tt> in
		### a derivative's initializer.
		def initialize( name, description )
			super()

			@name = name
			@description = description
		end


		### Class methods

		### Add the directories specified by <tt>dirs</tt> to the front of the
		### list to be searched by the factory method.
		def self.addServiceDirectories( *dirs )
			@@ServiceDirectories.unshift dirs
		end


		### Directory to look for services, relative to $LOAD_PATH (part of
		### PluginFactory interface)
		def self.derivativeDirs
			@@ServiceDirectories
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

