#!/usr/bin/ruby
#
# This file contains the MUES::IOEventFilter class, which is an abstract base
# class for filter objects in a MUES::IOEventStream. The filters act as links in
# a Chain of Responsibility([Design Patterns]), acting on the contents of
# MUES::IOEvent objects which are passed up and down the stream, modifying them,
# creating events based on them, changing their own internal state or the state
# of an associated object based on them, or ignoring them, depending on the task
# which the filter is supposed to accomplish.
# 
# The IOEventFilter class and the IOEventStream also use the Observer pattern to
# avoid the need to poll each filter for pending events.
#
# == Synopsis
# 
#   require "mues/filters/IOEventFilter"
# 
#   class MyFilter < MUES::IOEventFilter
#     @@SortDisposition = 750
#     ...
#   end
# 
# == Rcsid
# 
# $Id: ioeventfilter.rb,v 1.12 2002/08/01 01:14:08 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "observer"

require "mues"
require "mues/Events"
require "mues/Exceptions"


module MUES

	# An abstract base filter class for MUES::IOEventStream objects. This class
	# implements the Comparable, Observable, and MUES::Debuggable interfaces.
	class IOEventFilter < Object ; implements Observable, Comparable, MUES::Debuggable, MUES::AbstractClass

		include MUES::TypeCheckFunctions

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.12 $ )[1]
		Rcsid = %q$Id: ioeventfilter.rb,v 1.12 2002/08/01 01:14:08 deveiant Exp $
		DefaultSortPosition = 500


		### Create a new filter, optionally setting the sort position to
		### the value specified.
		def initialize( order=nil )
			@sortPosition = if order.nil?
								if self.class.const_defined? "DefaultSortPosition"
									self.class.const_get :DefaultSortPosition
								else
									DefaultSortPosition
								end
							else
								order
							end

			raise TypeError, "Sort position: expected a Fixnum, not a #{@sortPosition.class.name}" unless
				@sortPosition.is_a?( ::Fixnum )
			raise ArgumentError, "Sort position must be between 0 and 1000" unless
				0 <= @sortPosition && @sortPosition <= 1000
			
			@queuedInputEvents = []
			@queuedInputEventsMutex = Mutex.new
			@queuedOutputEvents = []
			@queuedOutputEventsMutex = Mutex.new

			@isFinished = false

			super()
		end


		######
		public
		######

		# The sort position of the filter, which must be a Fixnum between 0 and 1000.
		attr_accessor	:sortPosition

		# The Array of input events which are pending injection into the stream.
		attr_reader		:queuedInputEvents

		# The Array of output events which are pending injection into the stream.
		attr_reader		:queuedOutputEvents

		# A flag for indicating that the filter is finished its role in the
		# stream, and should be removed.
		attr_reader		:isFinished
		alias :isFinished? :isFinished


		### Start filter notifications for the specified stream. Returns true on
		### success. Filter subclasses can override this method if they need to
		### do setup tasks before being added to the stream, but they should be
		### sure to call this class's implementation via <tt>super()</tt>, or
		### the filter will not notify the stream when events are pending.
		def start( streamObject )
			add_observer( streamObject )
			true
		end


		### Stop the filter notifications for the specified stream, returning
		### any final events which should be dispatched on behalf of the
		### filter. Filter subclasses can override this method if they need to
		### do cleanup tasks before being removed from the stream, but they
		### should be sure to call this class's implementation via
		### <tt>super()</tt>, or the filter will continue to notify the stream
		### of pending events.
		def stop( streamObject )
			delete_observer( streamObject )
			@isFinished = true if count_observers.zero?
			true
		end


		### Add input <tt>events</tt> for this filter to the queue of pending
		### events and notify the containing MUES::IOEventStream/s that there are
		### input events pending.
		def queueInputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::InputEvent )

			debugMsg( 1, "Queueing #{events.size} input events." )
			@queuedInputEventsMutex.synchronize {
				@queuedInputEvents += events
				changed( true ) unless @queuedInputEvents.empty?
			}
			debugMsg( 2, "#{@queuedInputEvents.size} input events now queued." )

			notify_observers( self, 'input' )
			return @queuedInputEvents.size
		end


		### Add output <tt>events</tt> for this filter to the queue of pending
		### events and notify the containing MUES::IOEventStream/s that there are
		### output events pending.
		def queueOutputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::OutputEvent )

			debugMsg( 1, "Queueing #{events.size} output events." )
			@queuedOutputEventsMutex.synchronize {
				@queuedOutputEvents += events
				changed( true ) unless @queuedOutputEvents.empty?
			}
			debugMsg( 2, "#{@queuedOutputEvents.size} output events now queued." )

			notify_observers( self, 'output' )
			return @queuedOutputEvents.size
		end


		### Comparison -- Returns -1, 0, or 1 if the receiver sorts higher,
		### equal to, or lower than the other filter object, respectively,
		### according to its sort position.
		def <=>( otherFilter )
			checkType( otherFilter, MUES::IOEventFilter )
			return ( @sortPosition <=> otherFilter.sortPosition ).nonzero? ||
				@muesid <=> otherFilter.muesid
		end


		### Process the specified input events and return any which are
		### unhandled or new. Events which are returned will be injected into
		### the stream. Filter subclasses should override this method if they
		### wish to process input events.
		def handleInputEvents( *events )
			@queuedInputEventsMutex.synchronize {
				events += @queuedInputEvents
				@queuedInputEvents.clear
			}
			return events.flatten
		end


		### Process the specified output events and return any which are
		### unhandled or new. Events which are returned will be injected into
		### the stream. Filter subclasses should override this method if they
		### wish to process output events.
		def handleOutputEvents( *events )
			events.flatten!

			@queuedOutputEventsMutex.synchronize {
				events += @queuedOutputEvents
				@queuedOutputEvents.clear
			}
			return events.flatten
		end


		### Return a stringified description of the filter.
		def to_s
			"%s filter [%d]" % [ self.class.name, @sortPosition ]
		end

	end # class IOEventFilter
end # module MUES

