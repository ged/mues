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
#   require 'mues/storableobject'
#
#	class MyObject < MUES::StorableObject
#	end
#
#	obj = MyObject::new
#	objId = obj.objectStoreId
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

require 'rbconfig'
require "mues.#{Config::CONFIG['DLEXT']}"

module MUES #:nodoc:

    # The base class for all objects which are storable in a
    # MUES::ObjectStore. MUES::StorableObjects can be polymorphically
    # represented with MUES::ShallowReference objects, which can be used by the
    # MemoryManager associated with the store to swap disused objects out of
    # memory temporarily.
    class StorableObject < MUES::PolymorphicObject; implements MUES::AbstractClass

		include MUES::TypeCheckFunctions

		### Class constants

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		# Initialize the object, adding <tt>muesid</tt> and <tt>objectStoreData</tt>
		# attributes to it. Any arguments passed are ignored.
		def initialize( *ignored )
			super()
			@objectStoreData = nil
		end


		### Copy initializer: copy state from the +original+ object to the
		### receiver.
		def initialize_copy( original )
			super

			# Deep copy all instance variables by default
			self.instance_variables.each {|ivar|
				oval = original.instance_variable_get( ivar )
				case oval
				when Numeric, NilClass, TrueClass, FalseClass, Symbol
					newval = oval
				else
					begin
						newval = oval.dup
					rescue ::Exception
						newval = oval
					end
				end
				self.instance_variable_set( ivar, newval )
			}
		end



		######
		public
		######

		# Return the ObjectStore data of the object. This is an attribute that
		# can be used by the ObjectStore backend to store meta-data about the
		# object, such as its rowid.
		attr_accessor :objectStoreData
		
		### The auto-generated object id used as the primary key in the
		### MUES::ObjectStore.
		alias :objectStoreId :muesid


		### Returns true if the receiver is a shallow reference to a
		### StorableObject.
		def shallow?
			false
		end


		### The visitor method for the MUES::ObjectSpaceVisitor. This method
		### calls #visit on its argument, with itself as the first argument, and
		### any other objects which should be visited as the second and
		### succeeding arguments.
		def accept( visitor )
			checkType( visitor, MUES::ObjectSpaceVisitor )
			return visitor.visit( self )
		end


		### Callback method for prepping the object for storage in an
		### ObjectStore. Should return a copy of itself suitable for
		### serialization (eg., with references flattened, un-serializable data
		### removed or preserved in some way, etc.). It may modify any attribute
		### except its <tt>muesid</tt>, provided, of course, that it can
		### reconstitute itself when its #awaken method is called. The
		### MUES::ObjectStore it is about to be stored in is given as the
		### <tt>objStore</tt> argument.
		def lull( objStore )
			duplicate = self.dup
			duplicate.lull!( objStore )
			return duplicate
		end


		### Like #lull, but modifies the receiver in place. Returns <tt>nil</tt>
		### if no modifications were made.
		def lull!( objStore )
			return nil
		end
		

		### Callback method for thawing after being retrieved from the
		### ObjectStore. Should return either itself, or a copy of itself which
		### has been prepared for use in some way (references restored,
		### un-serializable data reconstituted, etc.). The MUES::ObjectStore it
		### was retrieved from is given as the <tt>objStore</tt> argument.
		def awaken( objStore )
			self.awaken!( objStore )
			return self
		end

		
		### Like #awaken, but modifies the receiver in place. Returns
		### <tt>nil</tt> if no modifications were made.
		def awaken!( objStore )
			return nil
		end

    end # class StorableObject



    # A placeholder class for StorableObjects which have been swapped out of
    # memory and into the ObjectStore.
    class ShallowReference < MUES::PolymorphicObject

		include MUES::TypeCheckFunctions

		### Class constants

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		# Methods to not remove from the instances of this class
		@@PreservedMethods = %w{become polymorph muesid __send__ __id__}

		### This undefines all instance methods for this class so that any call
		### to an object will invoke #method_missing.
		public_instance_methods(true).each {|method|
			next if @@PreservedMethods.include? method
			undef_method( method.intern )
		}
		

		### Create and return a new MUES::ShallowReference object that will act
		### as a surrogate for the object specified by <tt>id</tt> in the given
		### <tt>objectStore</tt> (a MUES::ObjectStore). If the optional
		### <tt>indexTable</tt> is given, it must be a Hash of <tt>method =>
		### value</tt> pairs which will become read-only methods on the
		### reference. If no <tt>indexTable</tt> is given, the hash returned by
		### #get_index_values will be used instead.
		### 
		### Arguments:
		### [id]
		###   Either the object to reference, or an id that can be used to
		###   retrieve the actual object from the ObjectStore.
		### [objectStore]
		###   The MUES::ObjectStore which contains the real object
		### [indexTable]
		###   A Hash populated with the return values of each index, keyed by
		###   their respective index names.
		def initialize( obj, objectStore = nil, indexTable = nil )
			checkType( objectStore, MUES::ObjectStore, NilClass )
			checkEachType( indexTable.keys, String ) if indexTable

			super()

			if obj.kind_of? MUES::StorableObject
				@muesid = id.objectStoreId
				@indexTable = indexTable || {}
			else
				@muesid = obj.to_s
				@indexTable = {}
			end

			@objectStore = objectStore
		end


		### Marshal interface: Returns a partially-reconstituted
		### ShallowReference -- it will be non-functional until the #objStore
		### method is called with the current MUES::ObjectStore object.
		def ShallowReference.load( string )
			MUES::ShallowReference::new( string )
		end



		######
		public
		######

		### Marshal interface: Returns a serialized ShallowReference as a
		### String.
		def dump( depth )
			return @muesid
		end


		### Set the objectStore this reference points into, if not set
		### already. Calling this method more than once on a single object
		### raises an error.
		def objectStore=( store )
			raise RuntimeError, "Cannot reset objectStore" unless @objectStore.nil?
			checkType( store, MUES::ObjectStore )
			@objectStore = store
		end


		### Returns true if the object is a shallow reference
		def shallow?
			true
		end


		### Returns true if the reference doesn't yet have an associated
		### MUES::ObjectStore.
		def dangling?
			return @objectStore.nil?
		end


		### Reload the object this reference points to from the objectstore,
		### swap identities with it, and call the method on it.
		def method_missing( sym, *args )
			return @indexTable[sym.to_s] if @indexTable.has_key? sym.to_s

			raise RuntimeError, "Cannot use a dangling ShallowReference" unless @objectStore
			realObject = @objectStore.retrieve( @muesid )
			self.polymorph( realObject )

			# Now 'self' is realObject, realObject is the shallow ref...
			self.send( sym, *args )
		end


    end # class ShallowReference

end # module MUES

