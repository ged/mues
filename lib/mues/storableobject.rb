#!/usr/bin/env ruby
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
#   require "StorableObject"
#
#   fake_obj = StorableObject.new( an_id_in_,the_object_store )
#   fake_obj.read_only {|x| puts x.to_s}
#   puts fake_obj.to_s  #no longer fake
#
# == Description
#
#   This file contains the StorableObject class, for use with the ObjectStore.  It
#   inherits from PolymorphicObject to implement shallow references.  Objects of
#   class Storable Object have one attribute, the id of the object that should
#   actually be here.  Once the StorableObject is inspected or used in any way
#   (except the read-only methods), it is replaced by the object returned by a
#   database lookup.
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
# * Michael Granger <ged@FaerieMUD.org>
#

$: << ".."

require "PolymorphicObject"
require "ObjectStore"
require "md5"

module AbstractClass
  def AbstractClass.append_features( klass )
    klass.class_eval <<-"END"
    class << self
      def new( *args, &block )
	raise InstantiationError if self == #{klass.name}
	super( *args, &block )
      end
    end
    END
    super( klass )
  end
end

class InstantiationError < Exception; end

class StorableObject < PolymorphicObject; include AbstractClass

  attr_reader :objectStoreID
  ### This is the method for providing an id suitable for storing into the 
  ###   ObjectStore of your choice.  Please redefine this for situations in
  ###   which you desire different behavior - but be sure to attach it to the
  ###   attribute and give the same value if asked twice of the same object.
  def objectStoreID
    return @objectStoreID if @objectStoreID
    raw = "%s:%s:%.6f" % [ $$, self.id, Time.new.to_f ]
    @objectStoreID = MD5.new( raw ).hexdigest
  end
  
  ### Check to see if this object needs to be deleted by the ObjectStoreGC.
  ###   return true: object goes away
  ###   return false: object stays till its reference count goes to 1 (would be 
  ###                 zero, but one reference is kept by the ObjectStore system).
  def os_gc_mark
    false
  end

end

class ShallowReference < PolymorphicObject

  ### This undefines all the methods for this object, so that any call to it will
  ###   envoke #method_missing.
  public_instance_methods(true).each {|method|
    next if method == "become" or method == "__send__" or
      method == "__id__"
    undef_method( eval ":#{method}" )
  }
  
  #########
  protected
  #########

  ### Creates a new ShallowReference object
  ### arguments:
  ###   an_id - the stringy id value that is to be used to retrieve the actual
  ###           object from the objectStore
  ###   an_obj_store - the ObjectStore to get things from
  def initialize(an_id, an_obj_store)
    raise TypeError("Expected String but got #{an_id.type.name}") if
      ! an_id.kind_of?(String)
    raise TypeError("Expected ObjectStore but got #{an_id.type.name}") if
      ! an_obj_store.kind_of?(ObjectStore)
    @id = an_id
    @obj_store = an_obj_store
  end

  ######
  public
  ######

  ### Allows momentary access to the object from the database, by calling this method
  ###   and supplying a block.  No changes to the object made in the block will be
  ###   written to the database.
  def read_only(&block)
    obj = @obj_store._retrieve( @id )
    block.yield(obj)
  end

  ### When any other method is sent, become the object returned by the database,
  ###   and send again.
  def method_missing (*args)
    become( @obj_store._retrieve( @id ) )
    send args.shift, *args
  end

end
