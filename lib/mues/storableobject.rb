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
#

$: << ".."

require "PolymorphicObject"
require "ObjectStore"
require "MD5"

class StorableObject < PolymorphicObject; implements AbstractClass

  def objectStoreID
    raw = "%s:%s:%.6f" % [ $$, self.id, Time.new.to_f ]
    return MD5.new( raw ).hexdigest
  end

end

class ShallowReference < PolymorphicObject

  ### This undefines all the methods for this object, so that any call to it will
  ###   envoke #method_missing.
  self.public_instance_methods(true).each {|method|
    break if method == "become" or method == "__send__" or
      method == "__id__"
    undef_method( method )
  }

  #########
  protected
  #########

  ### Creates a new ShallowReference object
  def initialize(an_id, an_obj_store)
    @id = an_id
    @obj_store = an_obj_store
  end

  ######
  public
  ######

  ### Allows momentary access to the object from the database, by calling this method
  ###   and supplying a block.
  def read_only(&block)
    read_only = true
    obj = @obj_store._retrieve( @id, read_only )
    block.yield(obj)
  end

  ### When any other method is sent, become the object returned by the database,
  ###   and send again.
  def method_missing (*args)
    become( @obj_store._retrieve( @id ) )
    send args.unshift, *args
  end

end
