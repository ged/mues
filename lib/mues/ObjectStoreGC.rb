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
#   The user should supply two things to an ObjectStoreGC at creation.  First is
#   the symbol of the method to be used for 'mark'ing objects for deletion.  It
#   may involve time since last use, size, or anything really.  Second, a delay
#   for time inbetween invocations.  With the train scheme, this may not be that
#   important, but I've yet to do the tests to find out (well, at this time, i've
#   yet to implement it at all ^_^).
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
#

require "sync"

class ObjectStoreGC

 
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
	  @thread = Thread.new { _gc_routine() }
	  @shutting_down = false
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
	  unless val.kind_of?(Float) and val.between?(0,1) raise TypeError end
	  @mutex.sychronize( Sync::EX ) {
		  @trash_ratio = val
	  }
  end
  
  ### Runs the GC right now
  ### arguments:
  ###   trash_ratio - the percent of memory aloowed before GC stops
  alias :start :trash_ratio=

  ### Kills the garbage collector, first storing all active objects
  def shutdown
	  #oi.  what should happen here, i don't know.
	  #it'll need to go through every object it's keeping track of, and
	  #'delete' them into the database.
	  @shutting_down = true
	  @thread.join
  end

  ### Registers object(s) with the GC
  def register ( *objects )
	  @mutex.synchronize( Sync::EX ) {
		  @objects << objects.flatten
	  }
  end

  #########
  protected
  #########
  
  def _gc_routine
	  until(@shutting_down)
		  loop_time = Time.now
		  until (Time.new - loop_time >= @delay) Thread.stop end
		  _collect
	  end
  end

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

# Should the delay be fixed, or dependant on the trash_ratio vs. actual fill
# level (Fx: as the fill level is approached, decrease the delay to compensate
# for this).  the example had the fill level style....  hmmm.  it does seem
# cooler.

# Also, the train algorithm was intended for helping negate the individual time
# cost of each GC cycle.  while this may be necessary in some cases, won't this
# be such that all it's doing is sending a message to a database (ArunaDB), which
# is pretty multi-threaded and not too time costing.  Is it even advantageous to
# attempt to minimize the grouping of calls to that database?  the train algorithm
# does come with an typical overall time cost, at the return of rarified user
# waits...  I don't know, so i'm going to discuss it with someone first.
