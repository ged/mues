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

require "mues/Object"
require "mues/Service"
require "mues/Events"
require "mues/Exceptions"
require "mues/ObjectStore"

module MUES

	### Class for the ObjectStore system's Service interface to MUES
	class ObjectStoreService < MUES::Service

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.13 $ )[1]
		Rcsid = %q$Id: objectstoreservice.rb,v 1.13 2002/08/02 20:03:42 deveiant Exp $

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

		### Handle events which are requesting an adapter for this service.
		def handleGetServiceAdapterEvent (event)
			if event.name == @name
				*(event.args)

				store = MUES::ObjectStore::create( *(event.args) )
				event.callback.call( @objectStores[-1] )
			end
			return []
		end

	end

end
