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

    ### Class constants
	  #:!: MUES has its own, i shouldn't tread.
#    Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
#    Rcsid = %q$Id: objectstoreservice.rb,v 1.6 2002/03/19 08:35:14 stillflame Exp $

    #########
    protected
    #########

    ### Initialize a new ObjectStoreService object, passing in a hash of
    ### values with the following keys:
    ### 'name' -> the name to give this ObjectStoreService.
    ### 'mark' -> the symbol for the method to be used for marking objects for
    ###           garbage collection.
    ### 'GC_delay' -> the period of time inbetween garbage collection sweeps
    def initialize(name, filename=nil, objects=[], indexes=[],
		   serialize=nil, deserialize=nil, mark=:os_gc_mark, gc_delay=nil)
		#:TODO: find out why this doesn't work
#		registerHandlerForEvents(ObjectStoreGCEvent,
#								 CloseObjectStoreEvent,
#								 NewObjectStoreEvent,
#								 LoadObjectStoreEvent,
#								 StoreObjectEvent,
#								 RequestObjectEvent)
      @name = name
      @objectStore = ObjectStore.new(filename, indexes, serialize, deserialize)
      @gc = @objectStore.gc
    end

    ### Class methods
    class << self
      
		### Make sure no more objects are unsotred
		def atEngineShutdown( theEngine )
			###:!: maybe a GC function?
			###    this should also take care of the object store, no?
			###    will i have to wait for @gc.shutdown?
			@gc.shutdown
			@objectStore.close
      end

    end

    ######
    public
    ######

    ### Handle the events.

    def _handleCloseObjectStoreEvent (event)
		@objectStore.close
		@objectStore = nil
    end

	### handles the creation of new ObjectStore's
	### arguments (as passed to the event)
    ###   'filename' -> the filename of the ObjectStore to associate this with.
    ###   'indexes' -> an array of symbols corresponding to the methods that will
    ###                be used to generate the desired indices.
    ###   'serialize' -> the symbol for the method to be used for object
    ###                  serialization.
    ###   'deserialize' -> the symbol for the method to be used for object
    ###                    deserialization.
    def _handleNewObjectStoreEvent (event)
		@objectStore = ObjectStore.new( event.filename,
									    event.indexes,
									    event.serialize,
									    event.deserialize )
    end

	### handles the loading of ObjectStore's
	### arguments (as passed to the event)
	###   'filename' -> the filename of the ObjectStore config file (?)
    def _handleLoadObjectStoreEvent (event)
		@objectStore = ObjectStore.load( event.filename )
    end

	### Makes sure the GC is running, and optionally sets the trash_ratio
	### assumes an ObjectStore is open and active
    def _handleObjectStoreGCEvent (event)
		@gc ||= ObjectStoreGC.new( @objectStore )
		@gc.start( event.trash_ratio )
    end

	### All object storing is to be done through the garbage collector
    def _handleStoreObjectEvent (event)
		@gc.register( event.objects )
    end

    def _handleRequestObjectEvent (event)
		event.recipient = @objectStore.retrieve( event.obj_id )
		#is there a better way to do this?
    end

	### included to prevent MUES::Event::Handler#handleEvent from screaming
	def _debugMsg (*args)
	end
  end

end
