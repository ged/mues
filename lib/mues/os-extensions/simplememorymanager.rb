#!/usr/bin/ruby
# 
# A simple memory-management strategy class for MUES::ObjectStore -- a very
# simple manager that will swap disused objects out of memory at regular
# intervals. It does so by sending the MUES::ObjectSpaceVisitor it is given to
# all live objects at periodic intervals and swapping any that return true. This
# is not intended to be a very efficient collection strategy, but rather to
# provide basic functionality for testing and a starting point for more advanced
# algorithms. Iterations over large object spaces such as this are very
# resource-intensive, and an objectspace of more than a few hundred objects will
# almost certainly require a more sophisticated strategy.
# 
# This class is not intended to be loaded directly. It can be used by specifying
# 'Simple' as the fourth argument to MUES::ObjectStore#create, or by specifying
# 'Simple' in the class attribute of the <tt>memorymanager</tt> element of an
# <tt>objectstore</tt> section of the config file (see lib/mues/Config.rb for
# more).
#
# == Arguments
#
# This collector accepts the following configuration arguments 
#
# == Synopsis
# 
#   require 'mues/objectstore'
#
#   os = MUES::ObjectStore::load( 'foo', [], nil, 'Simple' )
#	...
# 
# == Version
#
#  $Id$
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

		### A simple memory-management class for MUES::ObjectStore objects. See
		### lib/mues/os-extensions/SimpleMemoryManager.rb for more.
		class SimpleMemoryManager < MUES::ObjectStore::MemoryManager

			### Class constants

			# SVN Revision
			SVNRev = %q$Rev$

			# SVN Id
			SVNId = %q$Id$

			# SVN URL
			SVNURL = %q$URL$

			### The symbol of the default method to call to "mark" objects.
			DefaultMarkMethod = :os_gc_mark

			### Create and return a new MemoryManager:
			### [objectStore]
			###   the  to use as the objectstore for 'swapped' objects
			### [interval]
			###   The minimum number of seconds between swap runs. Defaults to
			###   50.
			def initialize( *args )
				super( args )
				@interval = @config['interval']
			end

			#########
			protected
			#########

			### The memory management thread routine: Loops at most every @delay
			### seconds and calls #startCycle with the specified <tt>args</tt>.
			def managerThreadRoutine( visitor )

				until(@shutting_down)
					loop_time = Time.now
					startCycle( visitor )

					until (Time.new - loop_time >= @interval || @shutting_down) do
						Thread.pass
					end
				end

				return true
			end

			
			### The actual garbage collection algorithm, in this case the simplest we could think of.
			### Redefine for desired behavior.
			def startCycle( visitor )
				@mutex.synchronize( Sync::SH ) {
					@active_objects.each_value {|o|
						next if o.shallow?
						if( o.accept(visitor) )
							@mutex.synchronize( Sync::EX ) {
								@objectStore.store(o)
								o.polymorph(ShallowReference.new( o.objectStoreId, @objectStore ))
							}
						end
					}
				}
			end

		end # class SimpleMemoryManager
	end # class ObjectStore
end # module MUES

