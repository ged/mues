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
#:?: do i need to include the events, or does this even look at those objects?
require "ObjectStoreEvents"
require "ObjectStore"
require "ObjectStoreGC"

module MUES
  
  ### Class for the ObjectStore system's Service interface to MUES
  class ObjectStoreService < Service
    include Event::Handler

    ### Class constants
	  #:!: MUES has its own, i shouldn't tread.
#    Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
#    Rcsid = %q$Id: objectstoreservice.rb,v 1.3 2002/03/04 06:16:50 stillflame Exp $

    #########
    protected
    #########

    ### Initialize a new ObjectStoreService object, passing in a hash of
    ### values with the following keys:
    ### 'name' -> the name to give this ObjectStoreService.
    ### 'filename' -> the filename of the ObjectStore to associate this with.
    ### 'objects' -> an array of objects to be stored.
    ### 'indexes' -> an array of symbols corresponding to the methods that will
    ###              be used to generate the desired indices.
    ### 'serialize' -> the symbol for the method to be used for object
    ###                serialization.
    ### 'deserialize' -> the symbol for the method to be used for object
    ###                  deserialization.
    ### 'mark' -> the symbol for the method to be used for marking objects for
    ###           garbage collection.
    ### 'GC_delay' -> the period of time inbetween garbage collection sweeps
    def initialize(name, filename=nil, objects = nil, indexes = nil,
		   serialize = nil, deserialize = nil, mark = nil, gc_delay = nil)

### :!: This NEEDS lots of work.  do i let them pass everything into the initialization,
###     or do i make them use events?

		# :!: didn't work, didn't find out why not
#		registerHandlerForEvents(ObjectStoreGCEvent,
#								 CloseObjectStoreEvent,
#								 NewObjectStoreEvent,
#								 LoadObjectStoreEvent,
#								 StoreObjectEvent,
#								 RequestObjectEvent)
		@name = name
		if(filename)
			@objectStore = ObjectStore.new(filename)
		end
		###:?: maybe all this shouldn't happen here...
		@gc = ObjectStoreGC.new(@objectStore, mark, gc_delay)
    end

    ### Class methods
    class << self
      
		### Make sure no more objects are unsotred
		def atEngineShutdown( theEngine )
			###:!: maybe a GC function?
		  @gc.shutdown
      end

    end

    ######
    public
    ######

    ### Handle the events.

    def _handleCloseObjectStoreEvent (event)
    end

    def _handleNewObjectStoreEvent (event)
    end

    def _handleLoadObjectStoreEvent (event)
    end

    def _handleObjectStoreGCEvent (event)
    end

    def _handleStoreObjectEvent (event)
    end

    def _handleRequestObjectEvent (event)
    end

	def _debugMsg (*args)
	end
  end

end
