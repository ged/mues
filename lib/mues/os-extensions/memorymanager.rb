#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::MemoryManager class: an abstract
# base class for MUES::ObjectStore memory-management Strategy object classes.
#
# == Synopsis
# 
#   require 'mues/os-extensions/MemoryManager'
#
#   class MyMemoryManager < MUES::ObjectStore::MemoryManager
#       ...
#   end
# 
# == Rcsid
# 
# $Id: memorymanager.rb,v 1.3 2002/08/01 01:26:08 deveiant Exp $
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

require 'hashslice'
require 'sync'
require 'pp'

require 'mues'
require 'mues/Exceptions'
require 'mues/ObjectSpaceVisitor'

module MUES
	class ObjectStore

		### This class is the abstract base class for MUES::ObjectStore
		### memory-management Strategy classes. Derivatives of this class should
		### provide at least a protected method called #managerThreadRoutine,
		### which should take a MUES::ObjectSpaceVisitor object as its argument
		class MemoryManager < MUES::Object ; implements MUES::AbstractClass

			include MUES::TypeCheckFunctions, MUES::FactoryMethods

			### Class methods

			# Returns the directory objectstore extensions live under (part of
			# the FactoryMethods interface)
			def self.derivativeDirs
				return 'mues/os-extensions'
			end


			### Initializer

			### Create and return a new MemoryManager with the specified
			### <tt>backend</tt> (a MUES::ObjectStore::Backend derivative), and
			### the specified <tt>config</tt> hash.
			def initialize( backend, config = {} ) # :notnew:
				super()
				
				@backend		= backend
				@activeObjects	= {}
				@mutex			= Sync::new
				@managerThread	= nil
				@running		= false
				@config			= config
			end



			######
			public
			######

			# Running flag -- if true, the memory manager is currently running
			attr_reader :running
			alias :running? :running


			### Get the object associated with the specified id from the objects
			### registered with the MemoryManager.
			def []( *ids )
				@mutex.synchronize( Sync::SH ) {
					# @activeObjects[ *ids ]
					ids.collect {|id| @activeObjects[id]}
				}
			end


			### Starts the memory manager using the specified <tt>visitor</tt>
			### object.
			def start( visitor )
				checkType( visitor, MUES::ObjectSpaceVisitor )

				@running = true
				unless @managerThread && @managerThread.alive?
					@managerThread = Thread.new {
						Thread.current.abort_on_exception = true
						begin
							managerThreadRoutine( visitor )
						rescue Reload
							self.log.info( "Reloading #{self.inspect}" )
						rescue Shutdown
							self.log.info( "Shutting down #{self.inspect}" )
						end
						@running = false
					}
				end
			end


			### Restart the memory manager, clearing the current active objects
			### and returning them.
			def restart( visitor )
				objs = nil
				@mutex.synchronize( Sync::EX ) {
					objs = self.shutdown
					self.start( visitor )
				}

				return objs
			end
			

			### Kill the memory manager and return all active, non-shallow
			### objects.
			def shutdown
				@managerThread.raise Shutdown
				@managerThread.join
				return @activeObjects.values.reject {|o| o.shallow?}
			end


			### Registers the specified <tt>objects</tt> with the
			### memory-manager.
			def register( *objects )
				checkEachType( objects, MUES::StorableObject )

				@mutex.synchronize( Sync::EX ) {
					objects.each {|o|
						@activeObjects[o.objectStoreId] = o
					}
				}

				@activeObjects.rehash
			end


			### Clear the objectspace
			def clear
				self.log.notice( "Clearing active objectspace." )
				@mutex.synchronize( Sync::EX ) {
					@activeObjects.clear
				}
			end



			#########
			protected
			#########

			abstract :managerThreadRoutine

		end # class MemoryManager

	end # class ObjectStore
end # module MUES

