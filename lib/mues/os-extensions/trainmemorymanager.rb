#!/usr/bin/ruby
# 
# This file contains the TrainMemoryManager class: an incremental memory manager
# scheme, to allow for non-disruptive management of the ObjectStore system.
# 
# == Synopsis
# 
#   This is proof of concept only.  The actual implementation of an incremental
#   mature garbage collector using the train algorithm in ruby does not involve
#   reference counting of any kind.  See ImprovedTrainMemoryManager.rb for
#   details.
#
# Data structure:
# * Outer array - the train yard, with Trains in descending order of age (oldest
#	first)
#	* Trains - each train is a simple object with the following attributes:
#     * references out - an array of objects that are referenced by objects within
#		this train
#	  * cars - an array of Car objets.  each car is a simple object with the
#		following attributes:
#		* objects - an array of objects inside this car
#
#	The collection algorithm on the aforementioned data structure is as follows:
#   Two threads exist - one for the determination of an object's maturity, the
#   other for the incremental "deletion" of those objects.  Maturity is
#   determined by the ObjectSpaceVisitor#visit method, which is set by the
#   environment defining the object space, and is a simple boolean value as to
#   whether or not the environment has immediate need of said object.  This
#   should have nothing to do with reference counts.  Once "matured", an object
#   is passed onto the train-yard of the second thread.
#
#	The train thread is mostly just a continuous loop that calls one method and
#	pauses.  This pause is determined actively by looking at the ratio of mature
#	objects to total objects, and trying to maintain that at a certain level.
#	When the ratio has too much garbage, the pause length is shortened; when too
#	low, it is lengthened.  It can also be reset manually for a short-term
#	change in behavior by the train thread.
#
#	The method called from within the train thread does the following with the
#	train-yard: only one car is ever considered: the oldest (first) car of the
#	oldest (first) train.  (Without considering references, it would just be
#	collected at this point, but that's makes useless the train part of this
#	algorithm.)  Now, the references TO the objects in this car are considered.
#	If the only references that point to any objects in this car come from
#	objects on this train, the car is collected (or the whole train, as we'll
#	see later, but this could cause unacceptable lags for enormous structures).
#	Each object that IS referenced from outside this train is moved onto the
#	last (newest) train that references the object, or if the reference comes
#	from outside mature object space, the object is treated as a newly matured
#	object, and moved onto the last train in the yard.  The remaining objects
#	must have references within this train, and are therefor put onto the end of
#	this (the oldest) train.  In this way, it can be seen that datastructures
#	will all be kept together in a train, and that once the front car is
#	reference solely by objects within its train, the entire train must be a
#	single datastructure, and can therefore be removed entirely.
#
#	For information on what is modeled here, see:
#	http://www.daimi.aau.dk/~beta/Papers/Train/train.html
# 
# == Caveats
#
#	This is just proof of concept, and so isn't clean and professional, and is
#	not being maintained.  For actual use, please see
#	ImprovedTrainMemoryManager.rb.
#
# == Rcsid
# 
# $Id: trainmemorymanager.rb,v 1.7 2003/10/13 04:02:12 deveiant Exp $
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

require 'mues/object'

module MUES
	class ObjectStore
		### an incremental memory manager scheme, to allow for non-disruptive
		### management of the ObjectStore system.  note: this cannot be restart()ed.
		class TrainMemoryManager < MUES::ObjectStore::MemoryManager

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
			Rcsid = %q$Id: trainmemorymanager.rb,v 1.7 2003/10/13 04:02:12 deveiant Exp $

			######
			public
			######

			def initialize( *args )
				super( *args )
				@interval			= @config['interval']			|| 50
				@trainInterval		= @config['trainInterval']		|| 30
				@trainObjectRatio	= @config['trainObjectRatio']	|| 0.1
				@trainRatioAccuracy	= @config['trainRatioAccuracy']	|| .05
				@trainSize			= @config['trainSize']			|| 3
				@carSize			= @config['carSize']			|| 2**10
				@trainyard = Trainyard::new(self)
				@trainThread = nil
				@activeObjectReferences = {}
			end

			# the number of seconds between each manager thread interval
			attr_accessor :interval

			# the number of seconds between each train thread interval.  note
			# that this is set actively by the algorithm and any changes enacted
			# by setting it here will be temporary.
			attr_accessor :trainInterval

			# the ratio to maintain between number of mature objects and total
			# number of objects.
			attr_accessor :trainObjectRatio

			# the give or take of the trainObjectRatio - how close the ratio can
			# actually be without invoking interval changing.
			attr_accessor :trainRatioAccuracy

			# the number of objects allowed per car
			attr_accessor :carSize

			# the number of cars allowed per train before a new one is started.
			# this only applies to the youngest train.
			attr_accessor :trainSize

			# the active objects keyed to a list of every registered object that
			# references it.
			attr_accessor :activeObjectReferences

			# Caveat: this assumes that the references between objects does not
			# change after registration.  This will not be true for any real
			# system, but since reference tracking is being added simply for the
			# sake of argument, no effort was put into making this realistic.
			# The most correct way to have implemented this would be to have
			# altered Object to be able to know how many links there are to it
			# at any given time, or possibly tied into the hook of whenever any
			# variable is changed, and set the values that way.
			def register( *objs )
				super( *objs )
				@mutex.synchronize( Sync::EX ) {
					objs.each {|fresh|
						@activeObjectReferences[fresh] = []
						@activeObjects.each {|id,o|
							@activeObjectReferences[fresh] << o if
								o.instance_variables.include?(fresh)
							@activeObjectReferences[o] << fresh if
								fresh.instance_variables.include?(o)
						}
					}
				}
			end

			def restart(thread)
				@trainThread.raise Reload
				@trainThread.join
				super(thread)
			end

			def shutdown 
				@trainThread.raise Shutdown
				@trainThread.join
				super
			end

			# add functionality to the start method.
			def start( visitor )

				$stderr.puts "Starting TrainMemoryManager threads" if $debug

				super( visitor )

				unless @trainThread && @trainThread.alive?
					@trainThread = Thread.new {
						Thread.current.abort_on_exception = true
						begin
							trainManagingRoutine( visitor )
						rescue Reload
							# :TODO: Log?
						rescue Shutdown
							# :TODO: Log?
						end
					}
				end
			end

			#########
			protected
			#########

			# simple - calls startCycle, waits at least @interval time, then
			# starts over.  on shutdown, calls saveAllObjects.
			def managerThreadRoutine( visitor )
				begin
					while true
						loop_time = Time.now
						startCycle( visitor )
						
						until (Time.new - loop_time >= @interval) do
							Thread.pass
						end
					end
				ensure
					$stderr.puts "saveAllObjects being called" if $debug
					saveAllObjects()
				end
			end

			### The object maturation algorithm.  This gets run once a cycle.
			def startCycle( visitor )
				@mutex.synchronize( Sync::SH ) {
					@active_objects.each_value {|o|
						unless o.shallow?
							# maturity is a boolean - true means the object is mature
							maturity = o.accept(visitor)
							@trainyard.newlyMatured(o) if maturity
							$stderr.puts "object #{o.to_s} found to be mature" if $debug && maturity
						end
					}
				}
			end

			### Stores all the (non-shallow) objects in the object store.
			def saveAllObjects 
				@mutex.synchronixe( Sync::EX ) {
					@active_objects.each_value {|o|
						@objectStore.store(o) unless o.shallow?
					}
				}
				@active_objects.clear
				@activeObjectReferences.clear
				@trainyard.clear
			end

			# the train thread conroller routine.
			def trainManagingRoutine( visitor )
				while true
					loop_time = Time.now
					checkTrains( visitor )
					case @trainyard.objectCount / @active_objects.length
					when (@trainObjectRatio*(1-@trainRatioAccuracy))..(
							@trainObjectRatio*(1+@trainRatioAccuracy))
						#close enough, leave it alone.
					when @trainObjectRatio..1.0
						#too much trash, go faster
						@trainInterval *= .9
					when 0..@trainObjectRatio
						#too often, slow down
						@trainInterval *= 1.1
					end

					until (Time.new - loop_time >= @trainInterval) do
						Thread.pass
					end
				end
			end

			# checks the train yard for cars in need of deletion.  only looks at
			# one car each iteration - the first car on the first train.  the
			# train is then "deleted" or not based on the way the references
			# between trains are networked.  if it is not deleted, the objects
			# in the car are shuffled off to the newest train that references
			# them, or the newest train if the reference is from outside mature
			# object space, or to the end of the oldest train if not referenced.
			# Caveat: this assumes that once an object is declared mature, that
			# will not have changed by the time it gets deleted.
			def checkTrains( visitor )
				deleteTheTrain = true
				@trainyard[0][0].objects.each {|old|
					newest = nil
					@activeObjectReferences[old].each {|obj|
						# find which trains, if any, the reference to our object
						# comes from.
						residence = @trainyard.trains.reverse.collect {|t|
							t.hasObject?(obj) ? t : nil
						}.compact
						if residence.empty?
							# the reference to the mature object wasn't found in
							# any of the trains, meaning it comes from outside
							# of mature object space, and this object should be
							# moved to the end of the newest train.
							deleteTheTrain = false
							@mutex.synchronize( Sync::EX ) {
								@trainyard[0][0].objects.delete(old)
							}
							newlyMatured(old)
							break # no need to check any more references
						elsif residence[-1] == residence[0] && residence[0] == @trainyard[0]
							# this reference is on the same train, so do nothing
							# - will get moved to end of this train or deleted,
							# but not until the rest of this car is checked.
						else
							# otherwise, the reference is known to be in a
							# train, and the object should be put there.
							# :TODO:
							# for best behavior, check every reference, then put
							# it in with the youngest of those.
							deleteTheTrain = false
							@mutex.synchronize( Sync::EX ) {
								@trainyard[0][0].objects.delete(old)
								residence[-1].addObj(old)
							}
						end
					}
				}

				if deleteTheTrain
					# no outside references were found, so trash the whole train
					$stderr.puts "deleting a train of length #{@trainyard[0].length}" if $debug
					self.reclaim(@trainyard.shift.cars.collect {|c|
									 c.objects
								 }.flatten)
				else
					# some outside references were found, meaning the entire
					# train may not have been checked, so put this car, with all
					# its remaining objects, onto the end of this train, thus
					# maintaining any datastructures that span multiple cars.
					@trainyard.[0].cars.push( @trainyard[0].cars.unshift )
				end
			end

			# replace the object(s) with a shallow reference
			def reclaim( *objs )
				objs.to_a.each {|o|
					@mutex.synchronize( Sync::EX ) {
						@objectStore.store(o)
						o.polymorph(ShallowReference.new( o.objectStoreId, @objectStore ))
					}
				}
			end

			# A datastructure used to help facilitate incremental collection of
			# garbage that may contain structures which span more than the
			# designated increment size.
			class Trainyard < MUES::Object

				# makes a new Trainyard object
				def initialize( m_m )
					@memoryManager = m_m
					@trains = []
					@trains << MMTrain::new( m_m )
					@activeObjectReferences = m_m.activeObjectReferences
					@carSize m_m.carSize
					@trainSize = m_m.trainSize
				end

				def_delegators :@trains, *(Array.instance_methods - %w[inspect to_s])

				# return the maximum car size
				attr_reader :carSize

				# returns the number of objects in the trainyard
				def objectCount 
					@trains.inject(0) {|tot,train| tot + train.objectCount}
				end

				# takes a newly matured object and puts it into the trainyard.
				def newlyMatured( *newlies )
					@trains << MMTrain::new(@memoryManager) if
						@trains[-1].cars.length >= @trainSize
					@trains[-1].addObj(newlies)
				end

			end # class Trainyard

			class MMTrain < MUES::Object

				# creates a new MMTrain object, used in the train algorithm for
				# memory management.
				def initialize( m_m )
					$stderr.puts "creating a new train" if $debug
					@memoryManager = m_m
					@cars = []
					@activeObjectReferences = m_m.activeObjectReferences
					@cars << MMCar::new( m_m )
				end

				def_delegators :@cars, *(Array.instance_methods - %w[inspect to_s])

				# the array of cars on this train
				attr_accessor :cars

				# returns the number of objects in the trainyard
				def objectCount 
					@cars.inject(0) {|tot,car| tot + car.objectCount}
				end

				def addObj( *objs)
					@cars[-1].addObj(objs.slice!(0, (@cars[-1].spaceLeft))
					until objs.empty?
						@cars << MMCar::new(@memoryManager)
						@cars[-1].addObj(objs.slice!(0, @carSize))
					end
				end

			end # class MMTrain

			class MMCar < MUES::Object

				# creates a new MMCar object, used in the train algorithm for
				# memory management.
				def initialize( m_m )
					$stderr.puts "creating a new car" if $debug
					@memoryManager = m_m
					@objects = []
					@maxSize = m_m.car_size
					@activeObjectReferences = m_m.activeObjectReferences
					@size = 0
				end

				def_delegators :@objects, *(Array.instance_methods - %w[inspect to_s])

				# returns the number of objects in the trainyard
				def objectCount 
					@objects.length
				end

				# returns whether or not the car is full
				def full? 
					@maxSize <= @size
				end

				# returns the objects that belong to this car
				def objects 
					@objects
				end

				# returns the amount of space left on this car
				def spaceLeft 
					@maxSize - @size
				end

				# puts the object(s) into the car, or raises a TrainError if there
				# isn't sufficent room on this car.  currently only counts each
				# object as 1 space, not taking into account instance vars that
				# aren't StorableObjects, or even just looking at Marshal.dump
				# return length.  this also doesn't handle reassigning the 
				def addObj( *obj )
					obj.to_a.each {|o|
						@size = @size + 1
						@mutex.synchronize( Sync::EX ) {
							@objects << o
						}
					}
					@objects.compress! # get rid of duplicates
				end

			end # class MMCar

			class TrainError < Exception; end
		end # class TrainMemoryManager

	end # class ObjectStore
end # module MUES
