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
#   ...uh, i'm not really sure how services are implemented through mues,
#      but it involves creating events for the service to handle.  for more
#      info on specific usage of this service, see the postscript or uml
#      files included.
#   
# == Caveats
#
#   All objects stored must inherit from the class StorableObject, for
#   the required ability to be a shallow reference and for the finalizer
#   that sends an event for the object to be stored before it's deleted.
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
#

require "mues"
require "mues/Service"
require "ObjectStoreEvents"
require "ObjectStore"

module MUES
  
  ### Class for the ObjectStore system's Service interface to MUES
  class ObjectStoreService < Service
    include Event::Handler

    ### Class constants
    Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
    Rcsid = %q$Id: objectstoreservice.rb,v 1.2 2002/02/24 07:00:26 stillflame Exp $

    #########
    protected
    #########

    ### Initialize a new ObjectStoreService object, passing in a hash of
    ### values with the following keys:
    ### 'objects' -> an array of objects to be stored.
    ### 'name' -> the name to give this ObjectStore.
    ### 'indexes' -> an array of symbols corresponding to the methods that will
    ###              be used to generate the desired indices.
    ### 'serialize' -> the symbol for the method to be used for object
    ###                serialization.
    ### 'deserialize' -> the symbol for the method to be used for object
    ###                  deserialization.
    ### 'mark' -> the symbol for the method to be used for marking objects for
    ###           garbage collection.
    ### 'GC_delay' -> the period of time inbetween garbage collection sweeps
    def initialize
    end

    ### Class methods
    class << self
      
      ### Make sure no more objects are unsotred
      def atEngineShutdown( theEngine )
      end

    end

    ######
    public
    ######

    ### Handles the  event.
    
  end
end




