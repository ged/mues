#!/usr/bin/ruby -w
#
# This file contains the MUES::StorableObject and MUES::ShallowReference
# classes. MUES::StorableObject is the abstract base class for all objects which
# can be stored in a MUES::ObjectStore, and MUES::ShallowReference objects can
# be used to maintain "shallow" references to objects in the store, lazily (and
# transparently) loading the real object back into memory as it is needed.
#
# == Synopsis
#
#   require "mues/StorableObject"
#
#	class MyObject < MUES::StorableObject
#	end
#
#	obj = MyObject::new
#	objId = obj.objectStoreID
#	objectStore.register( obj )
#
#	# ...later...
#	obj = objectStore.retrieve( objId )
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

require "mues.so" # For Polymorphic
require "mues/ObjectStore"
require "mues/Exceptions"


module MUES

    # The base class for all objects which are storable in a
    # MUES::ObjectStore. MUES::StorableObjects can be polymorphically
    # represented with MUES::ShallowReference objects, which can be used by the
    # GarbageCollector associated with the store to swap disused objects out of
    # memory temporarily.
    class StorableObject < MUES::PolymorphicObject; implements MUES::AbstractClass

		include MUES::TypeCheckFunctions

		### Initialize the StorableObject, adding an <tt>objectStoreID</tt>
		### instance variable that will be used as the primary key of the object
		### in the ObjectStore.
		def initialize # :nonew:
			super()
		end

		### The auto-generated object id used as the primary key in the
		### MUES::ObjectStore.
		alias :objectStoreID :muesid

		### Returns true for objects which are ShallowReferences to real
		### objects.
		def shallow?
			false
		end

		### The visitor method for the StorableCollectorVisitor. This should call
		### the <tt>visit</tt> method on the visitor with 
		def os_gc_accept( visitor )
			checkType( visitor, MUES::ObjectStore::GarbageCollectorVisitor )
			return visitor.visit( self )
		end


		### equality by objectStoreID
		def ==( an_other )
			objectStoreID == an_other.objectStoreID
		end

    end


    # A placeholder class for StorableObjects which have been swapped out of
    # memory and into the ObjectStore.
    class ShallowReference < MUES::PolymorphicObject

		### This undefines all instance methods for this class, so that any call
		### to an object will invoke #method_missing.
		public_instance_methods(true).each {|method|
			next if method == "become" or method == "__send__" or
				method == "__id__"
			undef_method( method.intern )
		}
		

		### Create and return a new ShallowReference object that will become the
		### actual database object when a real method is called on it.
		### arguments:
		### [an_id] the stringy id value that is to be used to
		### retrieve the actual object from the objectStore
		### [an_obj_store] the ObjectStore this belongs to
		### [some_values] a hash populated with the String return
		### values of each index, keyed by their respective index
		### names
		def initialize( an_id, an_obj_store, some_values = nil )
			raise TypeError, "Expected ObjectStore but got #{an_id.type.name}" unless
				an_obj_store.kind_of?(MUES::ObjectStore)

			@id = an_id.to_s
			@obj_store = an_obj_store
			@values = some_values ? some_values : get_index_values()
		end


		#########
		protected
		#########

		# gets the return values of the indexed methods
		def get_index_values
			hash = Hash.new
			obj = @obj_store.retrieve(@id)
			@obj_store.indexes.each {|ind|
				hash[ind] = obj.send(ind)
			}
			return hash
		end

		######
		public
		######

		### Returns true if the object is a shallow reference
		def shallow?
			true
		end
		
		### The id is something that a lookup isn't needed for
		def objectStoreID
			@id
		end

		### [MG]: Moved the do_read_only method to ObjectStore.

		### equality by objectStoreID
		def ==( an_other )
			objectStoreID == an_other.objectStoreID
		end


		### Reload the object this reference points to from the objectstore,
		### swap identities with it, and call the method on it.
		def method_missing (*args)
			if @values.exists?(args[0])
				@values[args[0]]
			else
				thingy = @obj_store.retrieve( @id )
				
				if( thingy.shallow? or ! thingy.respond_to?(args[0]) )
					super
				else
					become(thingy)
					send args.shift, *args
				end
			end

		end


    end # class StorableObject


	# A subclass of ShallowReference that allows the object lookup to
	# be done using the index specified.
	class IndexedShallowReference < MUES::ShallowReference

		# Instantiate and return a shallow reference 
		# arguments:
		# [an_id]       the id of the objected referenced
		# [an_ostore]   the ObjectStore this belongs to
		# [some_index_values] a hash populated with the String return
		# values of each index, keyed by their respective indexes.
		# [an_index]    the A_Index to look up the object through
		def initialize ( an_id, an_ostore, a_main_index, some_index_values = nil )
			@id = an_id
			@obj_store = an_ostore
			@index = a_main_index
			@values = some_index_values
			add_indexes()
		end

		# When any other method is sent, become the object returned by the database,
		# and send again.
		def method_missing(*args)
			thingy = @obj_store.send( "_retrieve_by_#{@index.name}".intern, @id )
			
			if( ! thingy.respond_to?(args[0]) )
				super
			else
				become(thingy)
				send args.shift, *args
			end
		end

	end # class IndexedShallowReference

end # module MUES
