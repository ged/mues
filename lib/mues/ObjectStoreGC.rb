#!/usr/bin/ruby -w
#
# This file contains the class for the ObjectStore service, as it will be
# used by MUES.
#
# == Copyright
#
# Copyright (c) 2002 FaerieMUD Consortium, all rights reserved.
# 
# This is Open Source Software.  You may use, modify, and/or redistribute 
# this software under the terms of the Perl Artistic License, a copy of which
# should have been included in this distribution (See the file Artistic). If
# it was not, a copy of it may be obtained from
# http://language.perl.com/misc/Artistic.html or
# http://www.faeriemud.org/artistic.html).
# 
# THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTIBILITY AND
# FITNESS FOR A PARTICULAR PURPOSE.
#
# == Synopsis
#
#   require "ObjectStoreGC"
#
#   
# == Description
#
#   This is the meta-garbage collector that will delete objects into the database.
#   This will really just send events to the ObjectStoreService to have an object
#   put into the database.  The GC design scheme intended is the train scheme:
#   http://www.daimi.aau.dk/~beta/Papers/Train/train.html
#   
#   The user should supply a few things to an ObjectStoreGC at creation.  First is
#   the symbol of the method to be used for 'mark'ing objects for deletion.  It
#   may involve time since last use, size, or anything really.  Second, a delay
#   for time inbetween invocations.  With the train scheme, this may be a trash
#   ratio instead.  Third is the ObjectStore object to store the deleted objects
#   into.
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
# * Michael Granger <ged@FaerieMUD.org>
#

require "sync"

class ObjectStoreGC

  include Sync_m
 
  ### Initialize a new ObjectStoreGC object
  ### arguments:
  ###   objectStore - the ObjectStore to 'delete' objects to
  ###   mark - the symbol of the method to be used for 'mark'ing objects
  ###   algor_args - the arguments to pass to the GC algorithm (a Hash).
  ###                varies depending on algorithm.
  def initialize(objectStore, mark = :os_gc_mark, algor_args = {})
    raise TypeError.new("Expected ObjectStore but received #{objectStore.type.name}") unless
      objectStore.kind_of?(ObjectStore)
    
    @objectStore = objectStore
    @active_objects = @objectStore.active_objects
    @mark = mark
    @algor_args = algor_args
    @mutex = Sync.new
    @shutting_down = false
    @running = true
    @thread = Thread.new { Thread.current.abort_on_exception = true; _gc_routine(@algor_args); @running = false }

    return self
  end

  ######
  public
  ######

  attr_reader :shutting_down, :active_objects, :running

  def mark
    # :MG: Don't need to synchronize here, as return is an atomic operation...
    # @mutex.synchronize( Sync::SH ) {
      @mark
    # }
  end
  
  def algor_args
    # :MG: Don't need to synchronize here, as return is an atomic operation...
    # @mutex.synchronize( Sync::SH ) {
      @algor_args
    # }
  end
  
  def algor_args= (aHash)
    raise TypeError, "Expected Hash, got #{aHash.type.name}" unless
      aHash.kind_of? Hash

    @mutex.synchronize( Sync::EX ) {
      @algor_args = aHash
    }
  end
  
  ### Runs the GC right now
  ### arguments:
  ###   algor_args - the percent of memory aloowed before GC stops
  def start (aHash = nil)
    ( self.algor_args = aHash ) if aHash
    @shutting_down = false
    @running = true
    unless (!@thread.alive?)
      @thread = Thread.new { Thread.current.abort_on_exception = true; _gc_routine(@algor_args); @running = false }
    end
  end
    
  ### Kills the garbage collector, first storing all active objects
  def shutdown
    @shutting_down = true
    @thread.join
  end

  def alive?
	@thread.alive?
  end

  ### Registers object(s) with the GC
  def register ( *objects )
    objects.flatten!
    objects.compact!
    @mutex.synchronize( Sync::EX ) {
      objects.each {|o|
		raise TypeError.new("Expected a StorableObject but received a #{o.type.name}") unless
		  o.kind_of?(StorableObject)
		@active_objects[o.objectStoreID] = o
      }
    }
  end

  #########
  protected
  #########
  
  ### Loops every @delay seconds (or more) and calls the garbage collection algorithm.
  ### arguments:
  ###   aHash - of arguments for the algorithm.
  ### currently takes:
  ###   'trash_rate' - the time between invocations
  def _gc_routine(aHash)
    delay = aHash['trash_rate'] || 50

    until(@shutting_down)
      loop_time = Time.now
      _collect(aHash)

      # :MG: Moved this to the bottom of the loop to avoid calling _collect()
      # during shutdown. This has the added benefit of counting the time it
      # takes for _collect to run in the loop_time.
      until (Time.new - loop_time >= delay || @shutting_down) do
	# :MC: changed Thread.stop to Thread.pass, as a 'stop'ed thread needs another
	# thread to call 'run' before it can do anything.
	Thread.pass
      end
    end
    _collect_all(aHash) # :MC: after it shuts down, it should store every active object into
                 # the database.
    return true
  end
  
  ### The actual garbage collection algorithm, in this case the simplest we could think of.
  ### Redefine for desired behavior.
  def _collect(aHash)
    @mutex.synchronize( Sync::SH ) {
      @active_objects.each_value {|o|
		if( !o.shallow? )
		  if( o.send(@mark) )
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
  ### may take arguments from the same hash _collect does
  def _collect_all (aHash)
    @active_objects.each_value {|o|
      @objectStore.store(o) unless o.shallow?
    }
    @active_objects.clear
  end
  
end

#######
#NOTES#
#######

# The train algorithm was intended for helping negate the individual time
# cost of each GC cycle.
# The current algorithm is just the simplest we could think of: iterate over all
# objects and delete those that need it.
# Once the workings of train are understood, we should switch over.
