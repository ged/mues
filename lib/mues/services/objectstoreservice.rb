#!/usr/bin/ruby -w
#
# This file contains the class for the ObjectStore service, as it will be
# used by MUES.
#
# == Copyright
#
# Copyright (c) 2002 FaerieMUD Consortium, all rights reserved.
# 
# This is Open Source Software.  You may use, modify, and/or redistribute 
# this software under the terms of the Perl Artistic License, a copy of which
# should have been included in this distribution (See the file Artistic). If
# it was not, a copy of it may be obtained from
# http://language.perl.com/misc/Artistic.html or
# http://www.faeriemud.org/artistic.html).
# 
# THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTIBILITY AND
# FITNESS FOR A PARTICULAR PURPOSE.
#
# == Synopsis
#
#   require "mues"
#   require "mues/Service"
#   require "mues/Events"
#   require "ObjectStoreService"
#
#   event = MUES::ObjectStoreGCEvent.new
#   eventQueue.enqueue( event )
#
#   # for more info on specific usage of this service, see the postscript or uml
#   # files included.
#   
# == Caveats
#
#   All objects stored must inherit from the class StorableObject, for
#   the required ability to be a shallow reference.
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
#

require "mues"
require "mues/Service"
require "mues/Events"
require "mues/Exceptions"
require "ObjectStoreEvents"
require "ObjectStore"
require "ObjectStoreGC"

module MUES

  ### Class for the ObjectStore system's Service interface to MUES
  class ObjectStoreService < Service
    include Event::Handler

    #########
    protected
    #########

    ### Initialize a new ObjectStoreService object, passing in a hash of
    ### values with the following keys:
    def initialize()
      @objectStores = []
      @name = "ObjectStoreService"
      registerHandlerForEvents( GetServiceAdapterEvent )
    end

    ### Class methods
    class << self
      ### Make sure no more objects are unsotred
      def atEngineShutdown( theEngine )
	@objectStores.each {|os| os.close}
      end
    end

    ######
    public
    ######

    ### Handle the events.

    ### Check to see if anyone wants an ObjectStore
    def _handleGetServiceAdapterEvent (event)
      if (event.name == @name)
	@objectStores << ObjectStore.new(*(event.args))
	event.callback.call( @objectStores[-1] )
      end
      return []
    end

    ### included to prevent MUES::Event::Handler#handleEvent from screaming
    def _debugMsg (*args)
    end

  end

end
