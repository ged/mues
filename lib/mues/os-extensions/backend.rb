#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::Backend class: an abstract base
# class for ObjectStore storage backends.
# 
# == Synopsis
# 
#   require 'mues/os-extensions/Backend'
#
#   class MyBackend < MUES::ObjectStore::Backend
#       ...
#   end
# 
# == Rcsid
# 
# $Id: backend.rb,v 1.1 2002/05/28 21:15:47 deveiant Exp $
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

require 'mues'
require 'mues/Exceptions'


module MUES
	class ObjectStore < MUES::Object

		### This class is the abstract base class for MUES::ObjectStore
		### backends. Derivatives of this class provide an adapter-like
		### interface to a means of storing MUES::StorableObjects in some sort
		### of datastore, and must provide implementations for the following
		### methods:
		### [<tt>store</tt>]
		###	  
		class Backend < MUES::Object ; implements MUES::AbstractClass
			
			### Registry of derived Backend classes
			@@registeredBackends = {}

			### Class methods
			class << self

				### Register a Backend as available
				def inherit( subClass )
					truncatedName = subClass.name.sub( /(?:.*::)?(\w+)(?:Backend)?/, "\1" )
					@@registeredBackends[ subClass.name ] = subClass
					@@registeredBackends[ truncatedName ] = subClass
				end

				### Factory method: Instantiate and return a new Backend of the
				### specified <tt>backendClass</tt>, using the specified
				### <tt>objectStore</tt>, <tt>name</tt>, <tt>dump_undump</tt>
				### Proc, and <tt>indexes</tt> Array.
				def create( backendClass, objectStore, name, dump_undump, indexes )
					unless @@registeredBackends.has_key? backendClass
						self.loadBackend( backendClass )
					end

					@@registeredBackends[ backendClass ].new( objectStore,
															  name,
															  dump_undump,
															  indexes )
				end

				### Attempt to guess the name of the file containing the
				### specified backend class, and look for it. If it exists, and
				### is not yet loaded, load it.
				def loadBackend( className )
					modName = File.join( ObjectStore::BackendDir,
										 className.sub(/(?:.*::)?(\w+)(?:Backend)?/, "\1Backend") )

					# Try to require the module that defines the specified
					# backend, raising an error if the require fails.
					unless require( modName )
						raise ObjectStoreError, "No such backend class '#{className}'"
					end

					# Check to see if the specified backend is now loaded. If it
					# is not, raise an error to that effect.
					unless @@registeredBackends.has_key? className
						raise ObjectStoreError,
							"Loading '#{modName}' didn't define a backend named '#{className}'"
					end

					return true
				end
			end


			### Declare pure virtual methods for required interface
			abstract :store,
				:retrieve,
				:retrieve_by_index,
				:retrieve_all,
				:lookup,
				:close,
				:exists?,
				:open?,
				:entries,
				:clear
		end

	end # class ObjectStore
end # module MUES

