#!/usr/bin/ruby
# 
# This file contains the GarbageCollector class: an abstract base class for ObjectStore garbage-collection strategy object classes..
# 
# == Synopsis
# 
#   require 'mues/os-extensions/GarbageCollector'
#
#   class MyGarbageCollector < MUES::ObjectStore::GarbageCollector
#       ...
#   end
# 
# == Rcsid
# 
# $Id: memorymanager.rb,v 1.1 2002/05/28 21:15:47 deveiant Exp $
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
		### garbage-collectors. Derivatives of this class should provide at least
		### a protected method called #_gc_routine, which should run whatever
		### collection algorithm it implements periodically over the hash of
		### <tt>@active_objects</tt> until <tt>@shutting_down</tt> becomes
		### <tt>true</tt>.
		class GarbageCollector < MUES::Object ; implements MUES::AbstractClass

			extend Forwardable
			include Sync_m

			### Registry of derived GarbageCollector classes
			@@registeredGarbageCollectors = {}

			### Class methods
			class << self

				### Register a GarbageCollector as available (callback from
				### inheritance)
				def inherit( subClass )
					truncatedName = subClass.name.sub( /(?:.*::)?(\w+)(?:GarbageCollector)?/, "\1" )
					@@registeredGarbageCollectors[ subClass.name ] = subClass
					@@registeredGarbageCollectors[ truncatedName ] = subClass
				end

				### Factory method: Instantiate and return a new
				### GarbageCollector of the specified <tt>gcClass</tt>, that
				### talks to the specified <tt>objectStore</tt>.
				def create( gcClass, objectStore )
					raise ObjectStoreError, "No such gc class '#{gcClass}'" unless
						@@registeredGarbageCollectors.has_key? gcClass

					@@registeredGarbageCollectors[ gcClass ].new( objectStore )
				end

				### Attempt to guess the name of the file containing the
				### specified gc class, and look for it. If it exists, and
				### is not yet loaded, load it.
				def loadGc( className )
					modName = File.join( ObjectStore::BackendDir,
										className.sub(/(?:.*::)?(\w+)(?:GarbageCollector)?/,
													  "\1GarbageCollector") )

					# Try to require the module that defines the specified
					# gc, raising an error if the require fails.
					unless require( modName )
						raise ObjectStoreError, "No such gc class '#{className}'"
					end

					# Check to see if the specified gc is now loaded. If it
					# is not, raise an error to that effect.
					unless @@registeredGarbageCollectors.has_key? className
						raise ObjectStoreError,
							"Loading '#{modName}' didn't define a gc named '#{className}'"
					end

					return true
				end
			end


			### Create and return a new GarbageCollector:
			### [objectStore]
			###   the MUES::ObjectStore to use as the objectstore for 'swapped'
			###   objects
			### [visitorClass]
			###   the class to use for gathering objects to be swapped.
			def initialize( objectStore )
				checkType( objectStore, MUES::ObjectStore )

				super()
				
				@objectStore = objectStore
				@active_objects = Hash.new
				@mutex = Sync.new
				@shutting_down = false
				@running = true

			end


			######
			public
			######

			# Deletegate all hash-like methods to the <tt>active_objects</tt> hash
			def_delegators :@active_objects, *( Hash.instance_methods - ["to_s"] )


			# Garbage collector is shutting down
			attr_reader :shutting_down
			alias :shutting_down? :shutting_down

			# Garbage collector is running
			attr_reader :running
			alias :running? :running

			# The symbol of the method to call on objects to test for freshness
			attr_reader :mark
			alias :markFunction :mark

			# The minimum number of seconds between garbage collection runs.
			attr_writer :trash_rate

			
			### Starts the garbage collector using the specified
			### <tt>visitor</tt> object.
			def start( visitor )
				checkType( visitor, MUES::ObjectStore::GarbageCollectorVisitor )

				@shutting_down = false
				@running = true
				unless @thread.alive?
					@thread = Thread.new {
						Thread.current.abort_on_exception = true
						begin
							_gc_routine( visitor )
						rescue Restart
							# Log?
						end
						@running = false
					}
				end
			end

			### Restart the garbage collector
			def restart( visitor )
				@running = false
				@thread.raise Restart
				@thread.join

				self.start( visitor )
			end
			
			### Kills the garbage collector, first storing all active objects
			def shutdown
				@shutting_down = true
				@thread.join
			end

			### Returns true if the garbage-collection thread is alive
			def alive?
				@thread.alive?
			end

			### Registers the specified <tt>objects</tt> with the GC
			def register ( *objects )
				objects.flatten!
				objects.compact!
				@mutex.synchronize( Sync::EX ) {
					objects.each {|o|
						checkType( o, MUES::StorableObject )
						@active_objects[o.objectStoreID] = o
					}
				}
			end

			#########
			protected
			#########

			abstract :_gc_routine

		end # class GarbageCollector

	end # class ObjectStore
end # module MUES

