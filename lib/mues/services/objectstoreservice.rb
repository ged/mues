#!/usr/bin/ruby -w
#
# This file contains the MUES::ObjectStoreService class, which is an ObjectStore
# service for MUES.
#
# == Synopsis
#
#    require 'mues/services/ObjectStoreService'
#
#
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
#
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "mues"
require "mues/Service"
require "mues/Events"
require "mues/Exceptions"
require "mues/ObjectStore"

module MUES

	### Class for the ObjectStore system's Service interface to MUES
	class ObjectStoreService < MUES::Service

		# Include the default event dispatcher method
		include MUES::Event::Handler

		### Initialize a new ObjectStoreService object, passing in a hash of
		### values with the following keys:
		def initialize()
			@objectStores = []
			@name = "ObjectStoreService"
			registerHandlerForEvents( MUES::GetServiceAdapterEvent )
		end

		### Class methods
		class << self
			### Make sure no more objects are unsorted
			def atEngineShutdown( theEngine )
				@objectStores.each {|os| os.close}
			end
		end


		#########
		protected
		#########

		### Check to see if anyone wants an ObjectStore
		def _handleGetServiceAdapterEvent (event)
			if (event.name == @name)
				store = ObjectStore.new(*(event.args))
				@objectStores << 
				event.callback.call( @objectStores[-1] )
			end
			return []
		end

	end

end
