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
  ###   trash_ratio - the percent of memory allowed to be trash
  ###   delay - the (seconds) delay between GC invocations
  def initialize(objectStore, mark = nil, trash_ratio = 0.1, delay = 50)
	  @objectStore = objectStore
	  @active_objects = @objectStore.active_objects
	  @mark = mark
	  @delay = delay
	  @trash_ratio = trash_ratio
	  @mutex = Sync.new
	  @shutting_down = false
	  @thread = Thread.new { _gc_routine() }
  end

  ######
  public
  ######

  def mark
    @mutex.sychronize( Sync::SH ) {
      @mark
    }
  end
  
  def trash_ratio
    @mutex.sychronize( Sync::SH ) {
      @trash_ratio
    }
  end
  
  def trash_ratio= (val)
    raise TypeError unless val.kind_of?(Float) and val.between?(0,1)
    @mutex.sychronize( Sync::EX ) {
      @trash_ratio = val
    }
  end
  
  ### Runs the GC right now
  ### arguments:
  ###   trash_ratio - the percent of memory aloowed before GC stops
  def start (ratio = @trash_ratio)
    trash_ratio=( val )
  end
    
  ### Kills the garbage collector, first storing all active objects
  def shutdown
    @shutting_down = true
    @thread.join
  end

  ### Registers object(s) with the GC
  def register ( *objects )
    @mutex.synchronize( Sync::EX ) {
      @objects |= objects.flatten #:MC: changed '<<' to '|=' to prevent duplicates
    }
  end

  #########
  protected
  #########
  
  ### Loops every @delay seconds (or more) and calls the garbage collection algorithm.
  def _gc_routine
    until(@shutting_down)
      loop_time = Time.now
      until (Time.new - loop_time >= @delay) do Thread.stop end
      _collect
    end
  end
  
  ### The actual garbage collection algorithm, in this case the simplest we could think of.
  ### Redefine for desired behavior.
  def _collect
    @mutex.synchronize( Sync::SH ) {
      @active_objects.each {|o|
	if(o.refCount == 1 or o.send(@mark))
	  @mutex.synchronize( Sync::EX ) {
	    @objectStore.store(o)
	    o.become(ShallowReference.new( o.objectStoreID ))
	  }
	end
      }
    }
  end
  
  #######
  private
  #######
  
  
end

#######
#NOTES#
#######

# Also, the train algorithm was intended for helping negate the individual time
# cost of each GC cycle.  while this may be necessary in some cases, won't this
# be such that all it's doing is sending a message to a database (ArunaDB), which
# is pretty multi-threaded and not too time costing.  Is it even advantageous to
# attempt to minimize the grouping of calls to that database?  the train algorithm
# does come with an typical overall time cost, at the return of rarified user
# waits...  I don't know, so i'm going to discuss it with someone first.
