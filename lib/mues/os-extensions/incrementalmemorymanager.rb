#!/usr/bin/ruby
# 
# This file contains the IncrementalMemoryManager class: the is a MemoryManager
# that came as a spin off to the TrainMemoryManager.  This does not, however,
# fully implement the train algorithm - rather, only those parts of the
# algorithm that apply within the context are used.
#
# Here's how things work.  There are two worker threads.  One continuously goes
# through the active objects and checks to see if any are mature, at which point
# the object is moved into mature object space.  The other thread continuously
# loops over the mature objects and deletes them.  Finally, there is a
# controller thread.  This thread starts the other two threads, waits a
# designated cycle length, then stops the threads, waits a designated interval
# length, and starts again.  This allows for a granularity in both the deletion
# of objects and the detection of their maturity.
#
# Also kept track of is the ratio between mature objects and all monitored
# objects.  When this ratio falls too far out of line of a supplied ratio, the
# intervals are adjusted to (hopefully) compensate.
# 
# == Synopsis
# 
#   (see MemoryManager.rb)
# 
# == Rcsid
# 
# $Id: incrementalmemorymanager.rb,v 1.2 2002/07/15 18:59:11 stillflame Exp $
# 
# == Authors
# 
# * Martin Chase <stillflame@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'mues'


module MUES

	class ObjectStore

		### the is a MemoryManager that came as a spin off to the
		### TrainMemoryManager.  This does not, however, fully implement the
		### train algorithm - rather, only those parts of the algorithm that
		### apply within the context of being a memory manager are used.
		class IncrementalMemoryManager < MUES::ObjectStore::MemoryManager

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
			Rcsid = %q$Id: incrementalmemorymanager.rb,v 1.2 2002/07/15 18:59:11 stillflame Exp $

			### Create a new IncrementalMemoryManager object.
			def initialize( *args )
				super( *args )
				@maturationThread = nil
				@collectorThread = nil
				@matureObjects = {}
				@interval		= @config['interval']		|| 50
				@cycleLength	= @config['cycleLength']	|| 10
			end

			# the number of seconds between each manager thread interval
			attr_accessor :interval

			# call super and start our own threads.
			def start( visitor )
				super( visitor )
				
				unless @collectorThread && @collectorThread.alive?
					@collectorThread = Thread.new {
						Thread.current.abort_on_exception = true
						begin
							collectorThreadRoutine( visitor )
						rescue Reload
							# :TODO: Log?
						rescue Shutdown
							# :TODO: Log?
						end
					}
				end

				unless @maturationThread && @maturationThread.alive?
					@matureationThread = Thread.new {
						Thread.current.abort_on_exception = true
						begin
							maturationThreadRoutine( visitor )
						rescue Reload
							# :TODO: Log?
						rescue Shutdown
							# :TODO: Log?
						end
					}
				end
			end

			# call super and reload our own threads
			def restart( visitor )
				@maturationThread.raise Reload
				@maturationThread.join
				@collectorThread.raise Reload
				@collectorThread.join
				super( visitor )
			end

			# call super and shutdown our own threads
			def shutdown 
				@maturationThread.raise Shutdown
				@maturationThread.join
				@collectorThread.raise Shutdown
				@collectorThread.join
				super()
			end
				

			#########
			protected
			#########

			# controller thread's main loop - start the threads, with
			# @cycleLength, stop the threads, wait @interval, repeat.
			def managerThreadRoutine( visitor )
				begin
					Thread.pass until @collectorThread && @maturationThread
					while true
						@collectorThread.start
						@maturationThread.start
						loop_time = Time.new
						Thread.pass until (Time.new - loop_time >= @cycleLength)

						@collectorThread.stop
						@maturationThread.stop
						loop_time = Time.new
						Thread.pass until (Time.new - loop_time >= @interval)
					end
				ensure
					saveAllObjects
				end
			end

			# continuously looping over mature object space, deleting everything
			# it finds.
			def collectorThreadRoutine( visitor )
				while true
					@mutex.synchronize( Sync::SH ) {
						@matureObjectSpace.each {|o|
							reclaim(o)
							@mutex.synchronize( Sync::EX ) {
								@matureObjectSpace.delete(o)
							}
						}
					}
				end
			end

			# continuously looping over active object space, maturing everything
			# that reponds true to the visitor.
			def maturationThreadRoutine( visitor )
				while true
					@active_objects.each {|o|
						if (! o.shallow?) && o.accept(visitor)
							@mutex.synchronize( Sync::EX ) {
								# use of a hash automatically takes care of duplicates.
								@matureObjectSpace[o] = nil
							}
						end
					}
				end
			end

			### Stores all the (non-shallow) objects in the object store.
			def saveAllObjects 
				@mutex.synchronixe( Sync::EX ) {
					@active_objects.each_value {|o|
						@objectStore.store(o) unless o.shallow?
					}
					@active_objects.clear
				}
			end

			# replace the object(s) with a shallow reference
			def reclaim( *objs )
				objs.to_a.each {|o|
					unless o.shallow?
						@mutex.synchronize( Sync::EX ) {
							@objectStore.store(o)
							o.become(ShallowReference.new( o.objectStoreID, @objectStore ))
						}
					end
				}
			end

		end # class IncrementalMemoryManager
	end # class ObjectStore
end # module MUES

