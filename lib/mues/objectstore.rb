#!/usr/bin/ruby -w
#
# This file contains the MUES::ObjectStore class, which is used to provide
# object persistance for MUES objects.
#
# The ObjectStore is a factory/wrapper class that provides a front end for
# combining a Strategy for object persistance (a MUES::ObjectStore::Backend)
# and, optionally, a one for swapping disused objects (mostly) out of memory
# temporarily via a MUES::ObjectStore::MemoryManager.
#   
# == Caveats/Requirements
#
# * All objects stored must inherit from the MUES::StorableObject class.
#
# * Multiple ObjectStores alive in the same ruby process must have distinct
#   names.
#
# == Specifying a Backend or MemoryManager
#
# <em>Not yet done.</em>
#
# == Synopsis
#
#   require "mues/ObjectStore"
#   require "mues/StorableObject"
#
#   $store = MUES::ObjectStore::create(
#		:backend	=> "BerkeleyDB",
#		:memmgr			=> "PMOS",
#		:name		=> "mystore"
#	)
#
#   objs = []
#   ids = []
#   40.times do
#	    newObj = MUES::StorableObject.new
#       objs << newObj
#       ids << newObj.objectStoreId
#   end
#
#   $store.store( *objs )
#   $store.retrieve_readonly {|obj| puts obj.attr}
#
#	object = $store.retrieve( "objid" )
#   object.attribute_A = 3.14159262546
#   $store.store( object )
#
#   $store.close
#
# == Version
#
#  $Id: objectstore.rb,v 1.36 2002/10/28 00:04:16 deveiant Exp $
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

require 'mues/Object'
require 'mues/Exceptions'
require 'mues/StorableObject'
require 'mues/ObjectSpaceVisitor'

module MUES

	# The ObjectStore provides a mechanism for object persistance and,
	# optionally, a way of swapping disused objects (mostly) out of memory
	# temporarily via a MemoryManager.
    class ObjectStore < MUES::Object

		include MUES::TypeCheckFunctions

		### Class constants
		Version	= %q$Revision: 1.36 $
		RcsId	= %q$Id: objectstore.rb,v 1.36 2002/10/28 00:04:16 deveiant Exp $

		# The default MemoryManager class
		DefaultMemMgr = "Null"

		# The default Backend class
		DefaultBackend = "Flatfile"

		# The default MemoryManager Visitor class
		DefaultVisitor = MUES::ObjectSpaceVisitor

		# The name of the subdirectory to load default backends and
		# memorymanager classes from (relative to $LOAD_PATH)
		BackendDir = 'mues/os-extensions'


		### Class globals

		# Instances of objectstores, keyed by name
		@@instances = {}


		#########
		# Class #
		#########

		### Disallow new() to prevent multiple instances of the same-named store
		private_class_method :new

		### Factory method: Combine the specified backend, memory manager,
		### and visitor objects together in a MUES::ObjectStore object. The
		### <tt>args</tt> are a Hash with the following keys:
		###
        ### [:name]
		###   A name (String) that acts as the store's unique
		###   identifier. Calling #load twice with the same name will return the
		###   previous one instantiated. <strong>Required</strong>.
		### [:backend]
		###   The name of the MUES::ObjectStore::Backend derivative to use, the
		###   class object itself, or an instance of a backend.  See the
		###   "Specifying a Backend or MemoryManager" section of
		###   lib/mues/ObjectStore.rb for more information.
		### [:memmgr]
		###   The name of the MUES::ObjectStore::MemoryManager derivative to
		###   use, the class object itself, or an instance of a memory
		###   manager. See the "Specifying a Backend or MemoryManager" section
		###   of lib/mues/ObjectStore.rb for more information.
		###
		### The following arguments are optional:
        ### [:indexes]
		###   An Array of symbols/strings for index methods. Index methods are
		###   methods which are to be used as index values to facilitate fast
		###   retrieval of objects from the store by lookups on values instead
		###   of by an id. See #lookup for more about how this works.
		### [:visitor]
		###   The MUES::ObjectSpaceVisitor derivative instance or class to use
		###   for traversing the objectspace contained in the store.
		### [:config]
		###   A configuration hash that contains one or more of the following
		###   keys. The value is used to configure the various parts of the
		###   objectstore at instantiation. The configuration values will be
		###   ignored if the corresponding part is specified by passing an
		###   instance instead of a Class or a name.
		###   [:memmgr]
		###      If specified, the value will be passed as the last argument to
		###      the MemoryManager on instantiation.
		###   [:backend]
		###      If specified, the value will be passed as the last argument to
		###      the Backend on instantiation.
		###   [:visitor]
		###      If specified, the value will be passed as the last argument to
		###      the Visitor on instantiation.
		def self.create( args )
			TypeCheckFunctions::checkResponse( args, :[] )

			config = args[:config] || {}

			# Check the name argument
			name = args[:name].to_s
			raise ArgumentError, "No name given." if name.empty?
			return @@instances[ name ] if @@instances.has_key?( name )

			# Check the indexes
			indexes = args[:indexes] || []
			TypeCheckFunctions::checkType( indexes, Array )
			TypeCheckFunctions::checkEachType( indexes, String, Symbol )

			# If they didn't supply a visitor, just use the default one
			args[:visitor] ||= DefaultVisitor
			if args[:visitor].is_a?( Class )
				visitor = args[:visitor].new( config[:visitor] )
			else
				TypeCheckFunctions::checkType( args[:visitor], MUES::ObjectSpaceVisitor )
				visitor = args[:visitor]
			end

			# Build the list of objects we need for the store
			backend	= 
				ObjectStore::Backend::create( args[:backend] || DefaultBackend,
											  name, indexes, config[:backend] )
			memmgr = 
				ObjectStore::MemoryManager::create( args[:memmgr] || DefaultMemMgr,
												    backend, config[:memmgr] )

			# Return the new store after adding it to the instance list
			return @@instances[ name ] = new( name, memmgr, backend, visitor )
		end


		### Initializes a new ObjectStore
		###
        ### [name]
		###   The store identifier
		### [memmgr]
		###   A MUES::ObjectStore::MemoryManager object.
		### [backend]
		###   A MUES::ObjectStore::Backend object.
		### [visitor]
		###   A MUES::ObjectSpaceVisitor object that will be used by the
		###   MemoryManager to traverse the objects that have been fetched
		###   from the store.
		def initialize( name, memmgr, backend, visitor ) # :notnew:
			super()

			@name			= name
			@mutex			= Sync.new
			@backend		= backend
			@memmgr			= memmgr
			@closed			= false

			@memmgr.start( visitor )
		end

		
		######
		public
		######

		# The name of the ObjectStore
		attr_reader :name

	
		# Returns <tt>true</tt> if the objectstore has been closed.
		def closed?
			@closed
		end

		
		### Stores the specified <tt>objects</tt> into the ObjectStore after
		### registering them with the MemoryManager.
		def store( *objects )
			@memmgr.register( *objects )
			self.put( *objects )
		end
		

		### Fetches and returns the MUES::StorableObject specifed by the given
		### <tt>ids</tt>, after registering the objects with the
		### MemoryManager.
		def retrieve( *ids )
			self.log.debug {"Retrieving #{ids.length} objects by id."}
			objs = @backend.retrieve( *ids )
			self.log.debug {"Retrieved #{objs.compact.length} objects."}
			return *self.restore( *objs )
		end


		### Fetch an Array of all objects stored in the ObjectStore.
		def retrieve_all
			objs = @backend.retrieve_all
			return *self.restore( *objs )
		end
		alias :retrieveAll :retrieve_all

		
		### Given a hash of index keys and values, fetch and return each object
		### that matches all of the specified pairs.
		def lookup( indexPairs )
			self.log.debug {"Looking up objects with #{indexPairs.length} search terms."}
			objs = @backend.lookup( indexPairs ) || []
			self.log.debug {"Lookup found #{objs.length} objects."}
			return self.restore( *objs )
		end


		### Removes the specified objects from the ObjectStore.
		def remove( *objects )
			@memmgr.unregister( *objects )
			@backend.remove( *objects )
		end

		
		### Preload the @active_objects with all objects that match the given
		### index name/value provided, or all objects if no arguments are used.
		###
		### Arguments:
		### [index_hash]
		###   Optionally, a hash of index to value(s) as per #lookup. Defaults
		###   to loading all objects in the store.
		def preload( index_hash = Hash.new )
			objs = ( (! index_hash.empty?) ? lookup(index_hash) : retrieve_all() )
			@memmgr.register( objs )
		end
		alias_method :pre_load, :preload


		### Allows momentary access to the object from the database, by calling
		### this method and supplying a block.  No changes to the object made in
		### the block will be written to the database.
		def fetch_read_only( id )
			raise ArgumentError, "Called without a block" unless
				block_given?
			obj = @memmgr[id] || self.fetch( id ).dup
			return yield( obj )
		end
		alias :fetchReadOnly :fetch_read_only
		alias :do_read_only :fetch_read_only
		alias :doReadOnly :fetch_read_only


		### Synchronizes the loaded objects with the data on disk.
		def sync
			@backend.store( *@memmgr.unswappedObjects )
		end


		### Closes the database.
		def close
			self.log.info( "Closing '#@name' objectstore" )
			objects = @memmgr.shutdown

			self.log.info { "Syncing objectspace (%d objects) to backing store" % objects.length }
			self.put( *objects )

			self.log.debug { "Closing backend" }
			@backend.close
		end


		### Returns <tt>true</tt> if an object with the specified <tt>id</tt>
		### exists in the ObjectStore.
		def exists?( id )
			@backend.exists?( id )
		end


		### Returns <tt>true</tt> if the ObjectStore is empty.
		def empty? 
			@backend.nitems == 0
		end

		
		### Returns the number of objects stored in the ObjectStore.
		def nitems
			@backend.nitems
		end
		alias :entries :nitems
		alias :size :nitems
		alias :count :nitems

		
		### Removes all objects from the ObjectStore.
		def clear
			@backend.clear
		end


		### Clear the objectspace, close the ObjectStore and remove the backing
		### store
		def drop
			self.log.notice( "Dropping objectstore '#@name'" )
			self.log.debug { "Calling shutdown() on the memory manager" }
			@memmgr.shutdown
			self.log.debug { "Calling clear() on the memory manager" }
			@memmgr.clear
			self.log.debug { "Calling drop() on the backend" }
			@backend.drop
		end


		### Add the specified <tt>indexes</tt>, which can be either Strings or
		### Symbols, to the objectstore.
		def addIndexes( *indexes )
			@backend.addIndexes( *indexes )
		end


		### Fetch all of the keys for the specified <tt>index</tt> and return
		### them as an Array.
		def indexKeys( index )
			@backend.indexKeys( index )
		end


		### Returns the objectstore as a human-readable string.
		def to_s
			"ObjectStore '%s' (%s/%s)" % [
				@name,
				@backend.class.name,
				@memmgr.class.name
			]
		end



		#########
		protected
		#########
		
		### Restores objects to the active objectspace, awakening and then
		### registering each object with the memory manager.
		def restore( *objs )
			return objs if objs.empty?
			self.log.debug {"Restoring #{objs.length} objects."}
			checkEachType( objs, MUES::StorableObject )

			self.log.debug {"Waking objects up for restore."}
			objs.each {|obj|
				raise "Farked object #{obj.inspect}" unless obj.respond_to?( :awaken! )
				obj.awaken!( self ) unless obj.nil?
			}

			@memmgr.register( *(objs.compact) )
			return objs
		end


		### Puts the specified MUES::StorableObjects into the backend datastore.
		def put( *objs )
			checkEachType( objs, MUES::StorableObject )
			@backend.store( objs.collect {|obj| obj.lull(self)} )
		end


		### Auto-generate singleton methods on the fly for retrieving objects
		### via an index.
		###
		### Methods that can be created:
		### [<tt>retrieve_by_<em>index</em>( value )</tt>] 
		###   Look up objects by the specified <tt>index</tt> and <tt>value</tt>
		###   and return them.
		def method_missing( sym, *args )
			methodName = sym.to_s

			# Look for a method pattern we know how to auto-define. If we find
			# one, add it to the instance.
			case methodName
			when /^retrieve_by_(\w+)$/
				idx = $1
				return super( sym, *args ) unless @indexes.has_key?( idx )
				code = %Q{
					def self.#{methodName}( val )
						*@backend.retrieve_by_index( :#{idx}, val )
					end
				}

			# Otherwise, just delegate the call to our parent's method_missing
			else
				return super( sym, *args )
			end

			# Evaluate the code, look up the new method, and call it with the
			# arguments we got.
			self.instance_eval code
			raise RuntimeError, "Method definition for '#{sym.to_s}' failed." if 
				method( methodName ).nil?
			self.method( sym ).call( *args )
		end



    end # class ObjectStore
end # module MUES


require 'mues/os-extensions/Backend'
require 'mues/os-extensions/MemoryManager'
