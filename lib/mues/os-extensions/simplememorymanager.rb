#!/usr/bin/ruby
# 
# A simple garbage-collection class for MUES::ObjectStore. It iterates over each
# object in the active object space each cycle, swapping out any that are marked
# as old.
# 
# == Synopsis
# 
#   require 'mues/ObjectStore'
#
#   os = MUES::ObjectStore::load( 'foo', [], nil, 'Simple' )
#	...
# 
# == Version
#
#  $Id: simplememorymanager.rb,v 1.1 2002/05/28 03:21:29 deveiant Exp $
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

module MUES
	class ObjectStore

		### A simple garbage-collection class for MUES::ObjectStore
		class SimpleGarbageCollector < MUES::ObjectStore::GarbageCollector

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
			Rcsid = %q$Id: simplememorymanager.rb,v 1.1 2002/05/28 03:21:29 deveiant Exp $

			### The symbol of the default method to call to "mark" objects.
			DefaultMarkMethod = :os_gc_mark


			### Create and return a new GarbageCollector:
			### [objectStore]
			###   the MUES::ObjectStore to use as the objectstore for 'swapped' objects
			### [mark]
			###   the symbol of the method to be used for 'mark'ing
			###   objects. Defaults to <tt>:os_gc_mark</tt>.
			### [trash_rate]
			###   The minimum number of seconds between garbage collection
			###   runs. Defaults to 50.
			def initialize( objectStore, trash_rate = 50 )
				@trash_rate = trash_rate
				@mark = mark

				super( objectStore )
				
				return self
			end



			#########
			protected
			#########

			### The garbage collection routine: Loops at most every @delay
			### seconds and calls #_collect with the specified <tt>args</tt>.
			def _gc_routine( visitor )

				until(@shutting_down)
					loop_time = Time.now
					_collect( visitor )

					until (Time.new - loop_time >= @trash_rate || @shutting_down) do
						Thread.pass
					end
				end

				_collect_all()
				return true
			end

			
			### The actual garbage collection algorithm, in this case the simplest we could think of.
			### Redefine for desired behavior.
			def _collect( visitor )
				@mutex.synchronize( Sync::SH ) {
					@active_objects.each_value {|o|
						if( !o.shallow? )
							if( o.os_gc_accept(visitor) )
								@mutex.synchronize( Sync::EX ) {
									@objectStore.store(o)
									o.become(ShallowReference.new( o.objectStoreID, @objectStore ))
								}
							end
						end
					}
				}
			end

			### Collects all the (non-shallow) objects.
			### may take arguments from the same hash _collect doesct
			def _collect_all
				@active_objects.each_value {|o|
					@objectStore.store(o) unless o.shallow?
				}
				@active_objects.clear
			end

		end # class SimpleGarbageCollector
	end # class ObjectStore
end # module MUES

