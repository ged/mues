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
#   require "ObjectStore"
#   require "StorableObject"
#
#   $store = ObjectStore.new("test_store")
#   objs = []
#   ids = []
#   40.times do
#      obj << StorableObject.new
#      ids << obj[-1].id
#   end
#   $store.store( objs )
#
#   #...
#
#   object = $store.retrieve( ids[12] )
#   object.read_only_do {|x| puts x}
#   object.attribute_A = 3.14159262546
#   $store.store( object )
#
#   $store.close
#
# == Description
#
#   This is the class that implements the storage and retrieval of objects for
#   the ObjectStoreService.  This will use ArunaDB as the database manager.
#
# == Caveats
#
#   All objects stored must inherit from the class StorableObject, for
#   the required ability to be a shallow reference.
#
#   The serialize methods must be implemented on the instance level of
#   all objects to be stored, and the deserialize method must be implemented
#   on the class level for all classes of objects to be stored.
#   Along these lines, class Class must implement the deserializer, and each
#   class to be stored must implement serialize on itself.  In these cases,
#   it is not necessary to completely serialize the class - just the name will
#   do, which the deserializer can simply eval to return a reference to the
#   Class object it represents.  This is because every object also has its class
#   stored with it, so that the deserialization method can be known.
#
#   Indexes, as passed to the 'new' method, must be in the form:
#      [[:meth1, ReturnClass1], [meth2, ReturnClass2], ...]
#   and the return classes can only be of the following:
#      * FixNum
#      * Time
#      * String
#   They should no arguments, and need not be implemented in all classes to be
#   stored.  If an object does not respond to a method, nil will be used.
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
# * Michael Granger <ged@FaerieMUD.org>
#

$: << "/home/touch/archives/arunadb_0_80" if File.directory?(
				"/home/touch/archives/arunadb_0_80" )

require "sync"
require "a_catalog" #arunadb file
require "a_table"   #arunadb file
require "StorableObject/StorableObject.rb"
require "ObjectStoreGC"

class ObjectStore

  include Sync_m

        TRASH_RATIO = .1
  
	#########
	# Class #
	#########

        ### Creates a new ObjectStore object, or loads it if it already exists
        ### (arguments are explained with initialize)
	def ObjectStore.new(filename, indexes = [], serialize = nil, deserialize = nil)
	  if File.exists?(filename)
	    file = File.open(filename)
	    conf = file.readlines.join('')
	    file.close
	    
	    name = ( %r~<name>(.*?)</name>~im.match(conf) )[1]
	    catl = ( %r~<catalog>(.*?)</catalog>~im.match(conf) )[1]
	    tabl = ( %r~<table>(.*?)</table>~im.match(conf) )[1]
	    inds = ( %r~<indexes>(.*?)</indexes>~im.match(conf) )[1].split( "," )
	    indexes = inds.collect {|i|
	      (meth,retu) = i.split(":")
	      [eval(":#{meth}"), eval(retu)]
	    }
	    the_cat = A_Catalog.use(catl)
	    the_table = A_Table.connect(tabl)
	    database = [the_cat, the_table]
	  else
	    database = nil
	  end
	  super(filename, database, indexes, serialize, deserialize)
	end

	### Loads in the specified config file, and returns the ObjectStore attached to it
	### arguments:
	###   filename - the filename of the ObjectStore config file (?)
	def ObjectStore.load (*args)
		ObjectStore.new(*args)
	end
		

	#########
	protected
	#########

	### Creates and returns an ArunaDB database - specifically an array of objects:
	### [A_Catalog, A_Table]
	### typical usage will usually only require accessing the A_Table object, but
	### the catalog should be kept alive (i think).
	### args:
	###   conf_filename - the name of the ObjectStoreConfig file to be
	def create_database(conf_filename)
	  basename = %r~(.*)(\..*)?~.match(conf_filename)[1]
	  cat_name = basename + ".ctl"
	  fs_name = basename
	  fs_filename = basename + "1.adb"
	  bt_name = basename
	  cat  = A_Catalog.new(cat_name)
	  fs   = A_FileStore.create(fs_name, 1024, fs_filename)
	  bt   = A_BTree.new(bt_name, fs_name)
	  cols = []
	  typ = ( @serialize ? "v" : "*" )
	  ###################   name type not_nil default constraint action display
	  cols << A_Column.new("id" , 'i', true  ,  nil  ,"%d > 0"  ,  nil , "%d"  )
	  cols << A_Column.new("obj", typ,  nil  ,  nil  ,   nil    ,  nil ,  nil  )
	  @indexes.each { |ind|
	    typ = get_type( ind[1] )  #should not be "*"
	    cols << A_Column.new( ind[0].id2name, typ )
	  }
	  pkeys= "id"
	  tabl = A_Table.new(bt_name, cols, pkeys)
	  return [cat,tabl]
	end

	### Returns the arunadb code for the type of storage to be used on a class.
	### Raises: TypeError if class isn't supported
	def get_type(aClass)
	  case aClass
	    when FixNum
	      "l"
	    when Time
	      "t"
	    when String
	      "v"
	    else
	      raise TypeError "Indexes cannot return objects of class %s" % aClass
	  end
	end

	### Initializes a new ObjectStore
	### arguments:
	###   filename - the filename to store the ObjectStore config file as
	###   database - the array of ArunaDB objects to be used for storing data
	###   indexes - a 2D array [ [method_symbol, return_class], ...]
	###   serialize - the symbol for the method to serialize the objects
	###   deserialize - the symbol for the method to deserialize the objects
	def initialize( filename, database, indexes = [],
		        serialize = nil, deserialize = nil )
	  @filename = filename
	  @indexes = indexes
	  @serialize = serialize || :_dump
	  @deserialize = deserialize || :_load
	  
	  add_indexes( @indexes )
	  
	  @database = database || create_database(@filename)
	  @table = @database[-1]
	  @table_mutex = Sync.new
	  @gc = ObjectStoreGC.new(self, :os_gc_mark)
	end
	
	######
	public
	######
	
	attr_reader :filename, :database, :serialize, :deserialize, :indexes,
	  :active_objects, :table

	### Stores the objects into the database
	### arguments:
	###   objects - the objects to store
	def store ( *objects )
	  objects.flatten!
	  index_names = @indexes.collect {|ind| ind[0].id2name}
	  index_returns = objects.collect {|o|
	    @indexes.collect {|ind|
	      o.send(ind[0])
	    }
	  }
	  ids = objects.collect {|o| o.objectStoreID}
	  serialized = objects.collect {|o| o.send(@serialize, -1)}
	  classes = objects.collect {|o| o.class.send(@serialize, 0)} #:?: what depth for classes?
	  #:?: or should classes be stored as keys that point to entries in the db?
	  trans = A_Transaction.new
	  col_names = ['id', 'obj', 'obj_class'] + index_names
	  ids.each_index do |i|
	    if @table.exists?(trans, ids[i])
	      #update(transaction, pkey, column_names, values)
	      @table.update(trans, ids[i], "obj", serialized[i])
	    else
	      @gc.register( objects[i] )
	      @table.insert( trans, col_names,
			    [ids[i], serialized[i], classes[i], index_returns[i]].flatten )
	    end
	    @indexes.each {|ind|
	      @table.update( trans, ids[i], ind[0].id2name, objects[i].send(ind) )
	    }
	  end
	  trans.commit
	end

	### Closes the database.
	def close 
	  @gc.shutdown
	  @table.close
	end
	
	### Opens the database again.  Starts a new garbage collector.
	### That is, if the database isn't already open.
	def open
	  @table.open if ! @table.open?
	  @gc.start( TRASH_RATIO )
	end

	### Gets the object specified by the given id out of the database
	### Well, not really.  returns a StorableObject style shallow reference
	def retrieve ( id )
	  ShallowReference.new( id )
	end

	### *ACTUALLY* gets the object specifed by the given id out of the database
	### arguments:
	###   id - the id (objectStoreID) of the object
	###   read_only - whether or not this lookup is read-only
	def _retrieve ( id , read_only = false )
	  table_data = (@table.find( nil, id )).obj
	  aClass = Class.send( @deserialize, table_data.obj_class )
	  object = aClass.send( @deserialize, table_data.obj )
	  if read_only
	    yield object
	  else
	    return object
	  end
	end

	def add_indexes ( *indexes )
	  @indexes << indexes.flatten
	  #:TODO: the auto-generation of 'retrieve_by_[index]' for each index.
	end

	def empty? 
	    @table.nitems == 0
	end

	def open? 
	  @table ? true : false
	end

	def entries 
	    @table.nitems()
	end
	alias size entries
	alias count entries

	def clear
	    @table.clear
	end
end
