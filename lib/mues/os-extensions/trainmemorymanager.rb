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
# == Rcsid
# 
# $Id: trainmemorymanager.rb,v 1.1 2002/07/10 05:07:05 stillflame Exp $
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
		### an incremental memory manager scheme, to allow for non-disruptive
		### management of the ObjectStore system.  note: this cannot be restart()ed.
		class TrainMemoryManager < MUES::ObjectStore::MemoryManager

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
			Rcsid = %q$Id: trainmemorymanager.rb,v 1.1 2002/07/10 05:07:05 stillflame Exp $

			######
			public
			######

			def initialize( *args )
				super( *args )
				@interval =
					@config.has_key?('interval') ?	@config['interval'] :
													50
				@carSize =
					@config.has_key?('carSize') ?	@config['carSize'] :
													2**10
				@trainRefCycle =
					@config.has_key?('trainRefCycle') ?	@config['trainRefCycle'] :
														10
				@trainObjectRatio =
					@config.has_key?('trainObjectRatio') ?	@config['trainObjectRatio'] :
															0.1
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

			# the number of trainThread cycles that won't have the references of
			# @activeObjects checked
			attr_accessor :trainRefCycle

			# the number of objects allowed per car
			attr_accessor :carSize

			# the active objects keyed to a list of every registered object that
			# references it.
			attr_accessor :activeObjectReferences

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

				super( thread )

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
					saveAllObjects()
					raise
				end
			end

			### The object maturation algorithm.  This gets started repeatedly.
			def startCycle( visitor )
				@mutex.synchronize( Sync::SH ) {
					@active_objects.each_value {|o|
						if( !o.shallow? )
							maturity = visitor.visit( o )
							if( maturity )
								@trainyard.newlyMatured(o)
							end
						end
					}
				}
			end

			### Stores all the (non-shallow) objects in the object store.
			def saveAllObjects 
				@active_objects.each_value {|o|
					@objectStore.store(o) unless o.shallow?
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
					
					until (Time.new - loop_time >= @trainInterval) do
						Thread.pass
					end
				end
			end

			# checks the train yard for cars in need of deletion.
			# should only look at one car each iteration - @trainyard[0][0] - the
			# first car on the first train.  the train is then "deleted" or not
			# based on the way the references between trains are networked.
			def checkTrains( visitor )
				@trainyard[0][0].objects.each {|old|
					deleteMe = true
					@activeObjectReferences[old].each {|ref|
						residence = @trainyard.trains.reverse.collect {|t|
							t.hasObject?(ref) t : nil
						}.compress
						if residence.empty?
							deleteMe = false
						elseif residence[0] == @trainyard[0]
							
						else
							deleteMe = false
						end
					}
				}

				if deleteMe
					self.delete(@trainyard.trains.shift.cars.collect {|c|
									c.objects
								}.flatten)
				else
					@trainyard.trains.push( @trainyard.trains.unshift )
				end
			end

			# replace the object with a shallow reference
			def delete( *objs )
				objs.to_a.each {|o|
					@mutex.synchronize( Sync::EX ) {
						@objectStore.store(o)
						o.become(ShallowReference.new( o.objectStoreID, @objectStore ))
					}
				}
			end

			#
			#
			class Trainyard #< MUES::Object

				# makes a new Trainyard object
				def initialize( m_m )
					@memoryManager = m_m
					@trains = []
					@trains << MMTrain::new( m_m )
					@activeObjectReferences = m_m.activeObjectReferences
				end

				# return the maximum car size
				def carSize 
					return @memoryManager.carSize
				end

				# takes a newly matured object and puts it into the trainyard.
				def newlyMatured( newly )
					refsFromObj = @activeObjectReferences[newly]
					@activeObjectReferences.delete(o)
					refsToObj = []
					@activeObjectRefences.each {|o,r|
						refsToObj << o if r.include?(newly)
					}
					@trains.each {|t|
						t.cars.each {|c|
							c.objects.each {|o,r|
								refsToObj << o if r[1].include?(newly)
							}
						}
					}
					# set parameter - the last train may only have 4 cars
					@trains << MMTrain::new(@memoryManager) if @trains[-1].cars.length > 3
					@trains[-1].addObj(newly, refsFromObj, refsToObj)
				end


			end # class Trainyard

			class MMTrain < Object

				# creates a new MMTrain object, with the specifed car size, or 1024
				# bytes.
				def initialize 
				end

				# the array of cars on this train
				attr_accessor :cars

				# the max size for the cars on this train
				attr_accessor :carSize

			end # class MMTrain

			class MMCar < MUES::Object

				def initialize( car_size = 2**10 )
					@objects = []
					@maxSize = car_size
					@size = 0
				end

				# returns the objects that belong to this car
				def objects 
					return @objects
				end

				# returns the amount of space left on this car
				def spaceLeft 
					return @maxSize - @size
				end

				# puts the object(s) into the car, or raises a TrainError if there
				# isn't sufficent room on this car.  currently only counts each
				# object as 1 space, not taking into account instance vars that
				# aren't StorableObjects, or even just looking at Marshal.dump
				# return length.  this also doesn't handle reassigning the 
				def addObjects( *obj )
					obj.to_a.each {|o|
						if @size + 1 > @maxSize
							raise TrainError, "Insufficient space to add an object to the car"
						else
							@size = @size + 1
							@objects << o
						end
					}
					@objects.compress! # get rid of duplicates
				end

			end # class MMCar

			class TrainError < Exception; end
		end # class TrainMemoryManager

	end # class ObjectStore
end # module MUES

# 								@mutex.synchronize( Sync::EX ) {
# 									@objectStore.store(o)
# 									o.become(ShallowReference.new( o.objectStoreID, @objectStore ))
