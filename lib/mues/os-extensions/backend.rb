#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::Backend class: an abstract base
# class for ObjectStore storage backends.
#
# Index methods, as named by those passed to the
# MUES::ObjectStore::Backend::create method, must return a String.  They should
# take no arguments, but need not be implemented in all classes to be stored.
# If an object does not respond to a method, nil will be used.
#
# == Synopsis
# 
#   require 'mues/os-extensions/Backend'
#   class FooBackend < MUES::ObjectStore::Backend
#       ...
#   end
#
#	ostore = MUES::ObjectStore::create( :backend => 'Foo', ... )
# 
# == Rcsid
# 
# $Id: backend.rb,v 1.5 2002/08/02 20:03:43 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'mues/Object'
require 'mues/Exceptions'
require 'mues/ObjectStore'

module MUES
	class ObjectStore

		### This class is the abstract base class for MUES::ObjectStore
		### backends. Derivatives of this class provide an adapter-like
		### interface to a means of storing MUES::StorableObjects in some sort
		### of datastore, and must provide implementations for the following
		### methods:
		### [<tt>store</tt>]
		###	  
		class Backend < MUES::Object ; implements MUES::AbstractClass
			
			include MUES::FactoryMethods

			### Class constants
			Version	= %q$Revision: 1.5 $
			RcsId	= %q$Id: backend.rb,v 1.5 2002/08/02 20:03:43 deveiant Exp $

			# The directory in which file-based objectstores will be kept,
			# relative to the base dir.
			StoreDir = "objectstores"

			# Default de/serializing proc
			DefaultSerializer = Proc.new {|obj|
				case obj
				when String
					Marshal.load( obj )
				when StorableObject
					Marshal.dump( obj )
				else
					raise ObjectStoreError, "Cannot serialize a #{obj.class.name}"
				end
			}


			### Class methods
			class << self
				alias_method( :__create, :create )
				remove_method( :create )
			end

			### (Overridden) Factory method: Instantiate and return a new
			### Backend of the specified <tt>backendType</tt>, using the
			### specified <tt>name</tt>, <tt>indexes</tt> Array, and
			### <tt>argHash</tt>.
			def self.create( backendType, name, indexes=[], configValue=nil )
				Dir::mkdir( StoreDir ) unless File.directory? StoreDir
				return __create( backendType, name, indexes, configValue )
			end


			### FactoryMethods callbacks

			# Returns the directory objectstores live under (part of the
			# FactoryMethods interface)
			def self.derivativeDirs
				return ['mues/os-extensions']
			end


			### Declare pure virtual methods for required interface
			abstract :initialize,
				:store,
				:retrieve,
				:retrieve_by_index,
				:retrieve_all,
				:lookup,
				:close,
				:exists?,
				:open?,
				:nitems,
				:clear,
				:drop
		end

	end # class ObjectStore
end # module MUES

