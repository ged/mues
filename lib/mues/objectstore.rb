# !/usr/bin/ruby -w
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
#      ids << obj[-1].objectStoreID
#   end
#   $store.store( objs )
#   #...or with garbage collection
#   $store.register( objs )
#   #...and watch as they disappear ^_^
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
#   The serializing Proc must be able to accept both a random StorableObject
#   and a String, to differentiate between the two, and to return an object of
#   the corresponding type (String for StorableObjects, a kind of StorableObject
#   for Strings).
#
#   Indexes, as passed to the 'new' method, must return strings.
#   They should take no arguments, but need not be implemented in all classes to be
#   stored.  If an object does not respond to a method, nil will be used.
#
#   Multiple ObjectStores alive in the same ruby process must have distinct names.
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
# * Michael Granger <ged@FaerieMUD.org>
#

$: << "/home/touch/archives/arunadb_0_80" if File.directory?(
				"/home/touch/archives/arunadb_0_80" )

require "a_catalog" #arunadb file
require "a_table"   #arunadb file
require "a_index"   #arunadb file
require "StorableObject/StorableObject.rb"
require "ObjectStoreGC"
require "sync"

class ObjectStore

  ### Example de/serializing proc
  @@prokie = Proc.new {|o|(o.kind_of?(String))?Marshal.load(o):Marshal.dump(o)}
  TRASH_RATE = 50 #seconds
  INDEXES_KEY = "indexes"

  #########
  # Class #
  #########

  ### Loads in the specified catalog, and returns the ObjectStore attached to it.
  ### Will create a new ObjectStore if file doesn't exist.
  ### arguments:
  ###   filename - the filename of the ObjectStore config file (?)
  def ObjectStore.load (*args)
    ObjectStore.new(*args)
  end
  

  #########
  protected
  #########

  ### Initializes a new ObjectStore
  ### arguments:
  ###   filename - the filename to store the ObjectStore config file as
  ###   dump_undump - the Proc to give an object to get a string and to give a
  ###                 string to get an object.
  ###   indexes - an array of symbols for index methods
  def initialize( filename, dump_undump, indexes = nil )
    @filename = filename
    @dump_undump = dump_undump
    @mutex = Sync.new
    @active_objects = Hash.new # the GC has responsibility for maintaining this

    if File.exists?(filename)
      @catalog = A_Catalog.use(filename)
      match = %r~(.*)(\..*)?~.match(filename) 
      @basename = match[1]
      raise "The '#{@basename}' table does not exist in the catalog contained in '#{filename}'." unless A_Table.exists?( @basename )
      @table = A_Table.connect( @basename )
      td = @table.find( nil, INDEXES_KEY )
      indexies = (td) ? td.obj : @dump_undump.call([])
      unpacked = @dump_undump.call( indexies )
      @indexes = Hash.new
      if (unpacked)
	unpacked.each {|ind|
	  if A_Index.exists?( nil, ind.to_s )
	    @indexes[ind] = A_Index.open( ind.to_s, @table.name )
	  end
	}
	add_index_methods( indexes )
      end
      @gc = ObjectStoreGC.new(self, :os_gc_mark, 'trash_rate' => TRASH_RATE)
      finalize
    else
      @indexes = Hash.new
      if (indexes && indexes.length > 0)
	indexes.each {|ind| @indexes[ind] = nil}
      end
      create_database(filename)
      add_index_methods( indexes )
      @gc = ObjectStoreGC.new(self, :os_gc_mark, 'trash_rate' => TRASH_RATE)
      finalize
    end
    
  end

  ### Creates and returns an ArunaDB database - specifically an array of objects:
  ### [A_Catalog, A_Table]
  ### typical usage will usually only require accessing the A_Table object, but
  ### the catalog should be kept alive (i think).
  ### args:
  ###   conf_filename - the name of the ObjectStoreConfig file to be
  def create_database(conf_filename)
    if ( match = %r~(.*)(\..*)?~.match(conf_filename) )
      @basename = match[1]
    else
      @basename = "object_store" + Time.now.to_i.to_s
    end
    cat_name = @basename
    fs_name = @basename
    fs_filename = @basename + "1.adb"
    locks_filename = @basename + "2.adb"
    @table_name = bt_name = @basename
    @catalog  = A_Catalog.use(cat_name)
    @lck_name = @basename + "locks"
    fs   = A_FileStore.create(fs_name, 1024, fs_filename)
    locs = A_FileStore.create(@lck_name, 1024, locks_filename)
    bt   = A_BTree.new(bt_name, fs_name)
    cols = []
    typ = "v"
    ###################   name type not_nil default constraint action display
    cols << A_Column.new("id" , 'v', true  ,  nil  ,   nil    ,  nil ,  nil  )
    cols << A_Column.new("obj", 'v',  nil  ,  nil  ,   nil    ,  nil ,  nil  )
    if (@indexes && @indexes.length > 0) 
      @indexes.each { |ind|
  	cols << A_Column.new( ind[0].id2name, 'v' )
      }
    end
    pkeys= "id"
    @table = A_Table.new(bt_name, cols, pkeys, fs_name, @lck_name)
    # add an A_Index object to @indexes for each entry
    if (@indexes && @indexes.length > 0)
      cols = ['id', 'obj']
      @indexes.each {|ind|
	cols.push( ind )
	@indexes[ind] = A_Index.new(ind, @table_name, cols, 'U', fs_name, @lck_name)
	cols.pop
      }
    end
  end

  # this writes the configuration information to the ArunaDB and 
  # freezes all unused attributes.
  def finalize
    indexies = @dump_undump.call(@indexes.keys)
    @mutex.synchronize( Sync::EX ) {
      trans = A_Transaction.new
      if @table.exists?(trans, INDEXES_KEY)
	#update(transaction, pkey, column_names, values)
	@table.update(trans, INDEXES_KEY, ['obj'], [indexies] )
      else
	@table.insert( trans, ['id', 'obj'], [INDEXES_KEY, indexies] )
      end
      trans.commit
    }
    instance_variables.each {|o| o.freeze unless o === @active_objects or o === @gc or o === @table}
    # brrrrrr....
  end

  ### Returns the arunadb code for the type of storage to be used on a class.
  ### Raises: TypeError if class isn't supported
  def get_type(aClass)
    raise TypeError.new( "Expected Class but received #{aClass.type.name}" ) unless
      aClass.kind_of?(Class)
    case aClass
    when Fixnum
      "l"
    when Time
      "t"
    when String
      "v"
    else
      raise TypeError.new( "Indexes cannot return objects of class %s" % aClass )
    end
  end

  ######
  public
  ######

  # filename - the name of the catalog file
  # catalog - the A_Catalog object
  # dump_undump - the Proc to control serialization and it's reverse, deserialization
  # indexes - a hash of A_Index objects, keyed by the symbol used to generate each
  # active_objects - a hash of objects currently recognized by this object store
  # gc - the garbage collection system for this object store
  # table_name - the name of the table objects are stored to
  attr_reader :filename, :catalog, :dump_undump, :indexes,
    :active_objects, :table, :gc, :table_name

  ### Stores the objects into the database
  ### arguments:
  ###   objects - the objects to store
  ### caveats:
  ###   aruna's docs say that while concurrant transactions work fine, their
  ###   multi-threaded capabilities haven't been fully tested.  who knows what
  ###   that's going to mean.
  def store ( *objects )
    (objects.kind_of?(Array)) ? objects.flatten! : (objects = [objects])
    raise("ObjectStore database not open.") unless (@table)
    index_names = @indexes.collect {|ind| ind[0].id2name}
    index_returns = objects.collect {|o|
      raise TypeError.new("Expected a StorableObject but received a #{o.type.name}") unless
	o.kind_of?(StorableObject)
      @indexes.collect {|ind|
	o.send(ind[0])
      }
    }
    ids = objects.collect {|o| o.objectStoreID}
    serialized = objects.collect {|o| @dump_undump.call(o)}
    @mutex.synchronize( Sync::EX ) {
      trans = A_Transaction.new
      col_names = ['id', 'obj'] + index_names
      ids.each_index do |i|
	if @table.exists?(trans, ids[i])
	  #update(transaction, pkey, column_names, values)
	  @table.update(trans, ids[i], col_names[1..-1],
			[serialized[i], index_returns[i]].flatten)
	else
	  @table.insert( trans, col_names,
			[ids[i], serialized[i], index_returns[i]].flatten )
	end
      end
      trans.commit
    }
  end

  ### registers objects with the garbage collector (so that they can be kept track
  ### of and 'deleted' when needed).
  def register (*objects)
    @gc.register(*objects)
  end
    
  ### fills in @active_objects with all db entries that match the given index
  ### name/value provided, or all objects if no arguements are used.
  ### arguments:
  ###   index_name - the name of the index to use
  ###   value - the value to search for
  ### default behavior is to assume no index and load all elements
  def pre_load (index_name = nil, value = nil)
    if(index_name)
      @active_objects |= eval("retrieve_all_by_#{index_name}(#{value})")
    else
      @table.each { |entry| @active_objects[entry.id] = [retrieve(entry.id)] }
    end
  end

  ### Closes the database.
  def close
    @gc.shutdown
    @table.close
    @catalog.close
    @table = nil
    @catalog = nil
  end

  ### Opens the database again.  Starts a new garbage collector.
  ### That is, if the database isn't already open.
  #	def open
  #	  (@table = A_Table.connect(@table_name)) if ! @table
  #	  @gc.start( 'trash_rate' => TRASH_RATE )
  #	end
  #:!: opening databases usually means flock problems

  ### Gets the object specified by the given id out of the database
  ### Well, not really.  returns a StorableObject style shallow reference
  def retrieve ( id )
    if ( an_obj = @active_objects[id] )
      return an_obj
    else
      an_obj = ShallowReference.new( id, self )
      @active_objects[id] = an_obj
      return an_obj
    end
  end

  ### *ACTUALLY* gets the object specifed by the given id out of the database
  ### arguments:
  ###   id - the id (objectStoreID) of the object
  def _retrieve ( id )
    if ( table_data = (@table.find( nil, id )) )
      return @dump_undump.call( table_data.obj )
    else
      return nil
    end
  end

  ### auto genererates methods for retrieving objects using the index names provided.
  ### each index must be accompanied by a corresponding method on the objects to be
  ### stored.  during db creation, each index will create an A_Index object to look
  ### through.
  ### methods created:
  ###   retrieve_by_[index] - make a ShallowReference with the right info.
  ###   _retrieve_by_[index] - grab the object, looking for the value provided first,
  ###                          then the id.
  ###   _retrieve_all_by_[index] - grabs all objects whose indexing method returns
  ###                              the value provided.
  def add_index_methods ( *indexes )
    indexes.flatten!
    indexes.each {|ind|
      ind_str = ind.to_s
      ObjectStore.class_eval <<-END

      def retrieve_by_#{ind_str} (id, val)
	ShallowReference.new(id, self, :_retrieve_by_#{ind_str}, val)
      end

      def _retrieve_by_#{ind_str} (id, val)
	if ( table_data = (@indexes[#{ind_str}].find( nil, id )) )
	  return @dump_undump.call( table_data.obj )
	else
	  return nil
	end
      end

      def _retrieve_all_by_#{ind_str} (val)
	if (val)
	  objs = []
	  @indexes[#{ind_str}].each(nil, [val], [val]) {|t_data|
	    objs << @dump_undump.call( t_data.obj )
	  }
	  return objs
	else
	  _retrieve_all
	end
      end

      END
    }
  end

  def _retrieve_all
    objs = []
    @table.each {|t_data|
      objs << @dump_undump.call( t_data.obj )
    }
    return objs
  end

  def exists? ( an_id )
    @table.exists?(A_Transaction.new, an_id)
  end
  
  def empty? 
    @table.nitems == 0
  end
  
  def open? 
    @table ? true : false
  end
  
  def entries 
    @table.nitems
  end
  alias size entries
  alias count entries
  
  def clear
    @table.clear
  end

end
