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
# $Id: memorymanager.rb,v 1.2 2002/07/09 15:09:25 deveiant Exp $
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

require 'mues'
require 'mues/Exceptions'
require 'mues/ObjectSpaceVisitor'

module MUES
	class ObjectStore < MUES::Object

		### This class is the abstract base class for MUES::ObjectStore
		### memory-management Strategy classes. Derivatives of this class should
		### provide at least a protected method called #managerThreadRoutine,
		### which should take a MUES::ObjectSpaceVisitor object as its argument
		class MemoryManager < MUES::Object ; implements MUES::AbstractClass

			include MUES::TypeCheckFunctions, MUES::FactoryMethods


			### Create and return a new MemoryManager with the specified
			### <tt>backend</tt> (a MUES::ObjectStore::Backend derivative), and
			### the specified <tt>config</tt> hash.
			def initialize( backend, config = {} ) # :notnew:
				super()
				
				@backend		= backend
				@activeObjects	= Hash::new
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
					@activeObjects[ *ids ]
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
							# :TODO: Log?
						rescue Shutdown
							# :TODO: Log?
						end
						@running = false
					}
				end
			end


			# :TODO: This may need a non-interruptive way of reloading to ensure
			# the memory manager doesn't get squashed in the middle of storing
			# an object or something.

			### Restart the memory manager
			def restart( visitor )
				@managerThread.raise Reload
				@managerThread.join

				self.start( visitor )
			end
			

			### Kills the memory manager after storing all active objects
			def shutdown
				@managerThread.raise Shutdown
				@managerThread.join
			end


			### Registers the specified <tt>objects</tt> with the memory-manager
			def register ( *objects )
				checkEachType( objects, MUES::StorableObject )

				@mutex.synchronize( Sync::EX ) {
					objects.each {|o|
						@activeObjects[o.objectStoreID] = o
					}
				}
			end



			#########
			protected
			#########

			abstract :managerThreadRoutine

		end # class MemoryManager

	end # class ObjectStore
end # module MUES

