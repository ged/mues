#!/usr/bin/ruby -w
#
# This file contains the MUES::ObjectStore class, which is used to provide
# object persistance for MUES objects.
#
# The ObjectStore is a factory/wrapper class that provides a front end for
# combining a Strategy for object persistance (a MUES::ObjectStore::Backend)
# and, optionally, a one for swapping disused objects (mostly) out of memory
# temporarily via a MUES::ObjectStore::GarbageCollector.
#   
# == Caveats/Requirements
#
# * All objects stored must inherit from the MUES::StorableObject class.
#
# * Multiple ObjectStores alive in the same ruby process must have distinct
#   names.
#
# == Synopsis
#
#   require "mues/ObjectStore"
#   require "mues/StorableObject"
#
#   $store = MUES::ObjectStore.load( "test_store" )
#   objs = []
#   ids = []
#   40.times do
#	    newObj = MUES::StorableObject.new
#       objs << newObj
#       ids << newObj.objectStoreID
#   end
#
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
# == Version
#
#  $Id: objectstore.rb,v 1.28 2002/06/04 07:03:47 deveiant Exp $
# 
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
# * Michael Granger <ged@FaerieMUD.org>
#
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#


require 'forwardable'
require 'sync'

require 'mues'
require 'mues/Exceptions'
require 'mues/StorableObject'
require 'mues/ObjectSpaceVisitor'

require 'mues/os-extensions/FlatfileBackend'
require 'mues/os-extensions/NullGarbageCollector'


module MUES

    # Exception class for ObjectStore errors
    def_exception :ObjectStoreException,	"Objectstore internal error",	MUES::Exception
	

	# The ObjectStore provides a mechanism for object persistance and,
	# optionally, a way of swapping disused objects (mostly) out of memory
	# temporarily via a GarbageCollector.
    class ObjectStore < MUES::Object

		include MUES::TypeCheckFunctions

		### Default de/serializing proc
		DefaultDumperProc = Proc.new {|obj|
			case obj
			when String
				Marshal.load( obj )
			when StorableObject
				Marshal.dump( obj )
			else
				raise ObjectStoreException, "Cannot serialize a #{obj.class.name}"
			end
		}

		### The default GarbageCollector class
		DefaultGcClass = MUES::ObjectStore::NullGarbageCollector

		### The default Backend class
		DefaultBackendClass = MUES::ObjectStore::FlatfileBackend

		### The default GarbageCollectorVisitor class
		DefaultGcVisitorClass = MUES::ObjectSpaceVisitor

		### The name of the subdirectory to load default backends and
		### garbagecollector classes from (relative to $LOAD_PATH)
		BackendDir = 'mues/os-extensions'


		### Class globals

		# Instances of objectstores, keyed by name
		@@instances = {}


		#########
		# Class #
		#########

		### Disallow new() to prevent multiple instances of the same-named store
		private_class_method :new

		### Load the specified catalog, and returns the ObjectStore attached to
		### it.  Will create a new ObjectStore if file doesn't exist.
		###
		### Arguments:
        ### name::         the store identifier
        ### indexes::      an Array of symbols/strings for index methods
        ### dump_undump::  the Proc to give an object to get a string and to give a
        ###                string to get an object.
		### gcClass::      The name of the garbage collector class to use.
		### backendClass:: The name of the backend class to use.
		def ObjectStore.load( name, indexes = [], dump_undump = DefaultDumperProc,
							 gcClass = DefaultGcClass, backendClass = DefaultBackendClass,
							 gcVisitor = DefaultGcVisitorClass, garbageCollectorArgs = {} )

			# Return either the instance with the specified name, or a new store
			# if there isn't one yet loaded.
			return @@instances[ name ] ||= ObjectStore.new( name, indexes, dump_undump,
														    gcClass, backendClass,
														    gcVisitor,
														    garbageCollectorArgs )
		end



		### Initializes a new ObjectStore
		###
		### Arguments:
        ### name::         the store identifier
        ### indexes::      an Array of symbols/strings for index methods
        ### dump_undump::  the Proc to give an object to get a string and to give a
        ###                string to get an object.
		### gcClass::      The name of the garbage collector class to use.
		### backendClass:: The name of the backend class to use.
		### gcVisitor::    An instance of MUES::ObjectSpaceVisitor
		###                or one of its derivative. If one is not provided, an
		###                instance of the DefaultGcVisitorClass is provided.
		def initialize( name, indexes, dump_undump, gcClass, backendClass,
					    gcVisitor, garbageCollectorArgs ) # :notnew:
			checkType( dump_undump, Proc, Method )
			checkType( gcClass, Class )
			checkType( backendClass, Class )

			super()

			@name			= name
			@indexes		= indexes
			@dump_undump	= dump_undump
			@mutex			= Sync.new
			@database		= Backend::create( backendClass, self, name, dump_undump, indexes )
			@gc				= GarbageCollector::create( gcClass, self )

			# Add accessors for the specified indexes
			add_index_methods( *indexes )

			# Start the garbage collector either with the visitor object
			# specified, or an instance of the default
			gcVisitor ||= DefaultGcVisitorClass::new
			@gc.start( gcVisitor )

			return self
		end


		#########
		protected
		#########

		### Auto-genererate methods for retrieving objects using the index names
		### provided.  Each index must have a corresponding method on the
		### objects to be stored.
		###
		### Methods created:
		### [<tt>retrieve_by_<em>index</em></tt>] 
		###   make a MUES::ShallowReference for the specified object.
		### [<tt>_retrieve_by_<em>index</em></tt>]
		###   grab the object, looking for the value provided first, then the
		###   id.
		### [<tt>_retrieve_all_by_<em>index</em></tt>]
		###   grabs all objects whose indexing method returns the value
		###   provided.
		def add_index_methods ( *indexes )
			indexes.flatten!
			indexes.each {|ind|
				ind_str = ind.to_s
				ObjectStore.class_eval <<-END
				
				def retrieve_shallow_by_#{ind_str}(id)
					register IndexedShallowReference.new( id, self, #{ind_str} )
				end
			
				def retrieve_by_#{ind_str}(id, val)
					@database.retrieve_by_index( id, #{ind_str} )
				end

				def retrieve_all_by_#{ind_str}(val)
					register @database.lookup( {#{ind_str} -> val} )
				end

				END
			}
		end


		######
		public
		######

		# the name of the catalog file
		attr_reader :name

		# the Proc to control serialization and it's reverse, deserialization
		attr_reader :dump_undump

		# a hash of A_Index objects, keyed by their names
		attr_reader :indexes


		### Stores the specified <tt>objects</tt> into the ObjectStore.
		def store ( *objects )
			@database.store( *objects )
		end

		### Registers the specified <tt>objects</tt> with the garbage collector
		### (so that they can be kept track of and swapped out of memory when
		### needed). If the object is not already stored in the ObjectStore, it
		### will be stored when it is swapped.
		def register (*objects)
			@gc.register(*objects)
		end

		### Removes the specified objects from the ObjectStore after
		### unregistering them.
		def remove( *objects )
			@database.remove( *objects )
		end

		### Unregisters the specified <tt>objects</tt> with the garbage
		### collector. The object will thenafter never be swapped out of memory
		### (unless it is re-registed, of course), but the last version of the
		### object will remain stored in the ObjectStore.
		def unregister( *objects )
			@gc.unregister( *objects )
		end
		
		### Preload the @active_objects with all objects that match the given
		### index name/value provided, or all objects if no arguments are used.
		###
		### Arguments:
		### [index_hash]
		###   Optionally, a hash of index to value(s) as per #lookup. Defaults
		###   to loading all objects in the store.
		def pre_load ( index_hash = Hash.new )
			objs = ( (! index_hash.empty?) ? lookup(index_hash) : retrieve_all() )
			@gc.register(objs)
		end

		### Allows momentary access to the object from the database, by calling
		### this method and supplying a block.  No changes to the object made in
		### the block will be written to the database.
		def do_read_only( id )
			obj = retrieve( id ).dup
			return yield( obj )
		end

		### Closes the database.
		def close
			@gc.shutdown
			@database.close
			@database = nil
			@gc = nil
		end

		### Fetches and returns the MUES::StorableObject specifed by the given
		### <tt>id</tt>.
		def retrieve( id )
			@gc[id] ||= @database[id]
		end

		### Gets and returns a MUES::ShallowReference to the object specified by
		### <tt>id</tt> out of the ObjectStore.
		def retrieve_shallow( id )
			@gc[id] ||= ShallowReference.new( id, self )
		end

		### Given a hash of index keys and values, fetch and return each object
		### that matches all of the specified pairs.
		def lookup( index_pairs )
			@database.lookup( index_pairs )
		end

		### Fetch an Array of all objects stored in the ObjectStore.
		def retrieve_all
			@database.retrieve_all
		end

		### Returns <tt>true</tt> if an object with the specified <tt>id</tt>
		### exists in the ObjectStore.
		def exists? ( id )
			@database.exists?( id )
		end

		### Returns <tt>true</tt> if the ObjectStore is empty.
		def empty? 
			@table.nitems == 0
		end
		
		### Returns <tt>true</tt> if the ObjectStore is currently open.
		def open? 
			@table ? true : false
		end
		
		### Returns the number of objects stored in the ObjectStore.
		def entries 
			@table.nitems
		end
		alias :size :entries
		alias :count :entries
		
		### Removes (unregisters) all objects from the ObjectStore.
		def clear
			@table.clear
		end


    end # class ObjectStore
end # module MUES

