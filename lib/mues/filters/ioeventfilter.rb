#!/usr/bin/ruby
#
# This file contains the MUES::IOEventFilter class, which is an abstract base
# class for filter objects in a MUES::IOEventStream. The filters act as links in
# a Chain of Responsibility
# (http://patterndigest.com/patterns/ChainOfResponsibili.html), acting on the
# contents of MUES::IOEvent objects which are passed up and down the stream,
# modifying them, creating other events based on them, changing their own
# internal state or the state of an associated object based on them, or ignoring
# them, depending on the task which the filter is supposed to accomplish.
# 
# This class also fulfills the <tt>Subject</tt> role of the
# <strong>Observer</strong> design pattern
# (http://patterndigest.com/patterns/Observer.html), with the
# MUES::IOEventStream as the <tt>Observer</tt> part. Filters notify the streams
# they are associated with when they have pending events.
#
# When you define a derivative of IOEventFilter, you will need to define a class
# constant called 'DefaultSortPosition', which is a number between 0 and 1000,
# inclusive. This number is used by the Comparable interface to determine the
# order in which filters should be sorted, and therefore the order in which they
# are given the IOEvents which have entered the stream. Lower values means the
# filter will sort more towards the <strong>output</strong> side of the stream,
# higher values sort towards the <strong>input</strong> side, and middle values
# generally act as modifying, macro, or duplicative filters.
#
# You can also pass a different sort order value for a specific instance to this
# class's #initialize method via <tt>super()</tt>.
#
# == Synopsis
# 
#   require 'mues/filters/ioeventfilter'
# 
#   class MyFilter < MUES::IOEventFilter
#     DefaultSortPosition = 550
#     ...
#	  def handleInputEvents( *events )
#	    ...
#	  end
#
#	  def handleOutputEvents( *events )
#	    ...
#	  end
#   end
# 
# == Subversion ID
# 
# $Id$
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

require 'mues/object'
require 'mues/mixins'
require 'mues/events'
require 'mues/exceptions'


module MUES

	# An abstract base filter class for MUES::IOEventStream objects. This class
	# implements the Comparable, Observable, and MUES::Debuggable interfaces.
	class IOEventFilter < MUES::Object
		implements Observable, Comparable, MUES::Debuggable, MUES::AbstractClass

		include MUES::TypeCheckFunctions

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# The numeric sort order constant -- determines where in an
		# IOEventStream the filter goes. Lower values means the filter will sort
		# more towards the <strong>output</strong> side of the stream, higher
		# values sort towards the <strong>input</strong> side, and middle values
		# generally act as modifying, macro, or duplicative filters.
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

			raise TypeError,
				"Sort position: expected a Fixnum, not a %s" %
				@sortPosition.class.name unless @sortPosition.is_a?( ::Fixnum )
			raise ArgumentError, "Sort position must be between 0 and 1000" unless
				0 <= @sortPosition && @sortPosition <= 1000
			
			@queuedInputEvents = []
			@queuedInputEventsMutex = Mutex.new
			@queuedOutputEvents = []
			@queuedOutputEventsMutex = Mutex.new

			@isFinished = false
			@stream = nil

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

		# The IOEventStream object which started the filter, if it is started.
		attr_reader		:stream

		# A flag for indicating that the filter is finished its role in the
		# stream, and should be removed. Aliases: #isFinished?, #finished?
		attr_reader		:isFinished
		alias :isFinished? :isFinished
		alias :finished? :isFinished


		### Start filter notifications for the specified +stream+. Returns an
		### array of events to propagated for startup. Filter subclasses can
		### override this method if they need to do setup tasks before being
		### added to the stream, but they should be sure to call this class's
		### implementation via <tt>super()</tt>, or the filter will not notify
		### the stream when events are pending.
		def start( stream )
			add_observer( stream )
			@stream = stream
			[]
		end


		### Stop the filter notifications for the specified +stream+, returning
		### any final events which should be dispatched on behalf of the
		### filter. Filter subclasses can override this method if they need to
		### do cleanup tasks before being removed from the stream, but they
		### should be sure to call this class's implementation via
		### <tt>super()</tt>, or the filter will continue to notify the stream
		### of pending events.
		def stop( stream )
			delete_observer( stream )
			@stream = nil
			@isFinished = true if count_observers.zero?
			[]
		end


		### Add input <tt>events</tt> for this filter to the queue of pending
		### events and notify the containing MUES::IOEventStream/s that there are
		### input events pending.
		def queueInputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::InputEvent )

			debugMsg( 4, "Queueing #{events.size} input events." )
			@queuedInputEventsMutex.synchronize {
				@queuedInputEvents += events
				changed( true ) unless @queuedInputEvents.empty?
			}
			debugMsg( 5, "#{@queuedInputEvents.size} input events now queued." )

			notify_observers( self, 'input' )
			return @queuedInputEvents.size
		end


		### Add output <tt>events</tt> for this filter to the queue of pending
		### events and notify the containing MUES::IOEventStream/s that there are
		### output events pending.
		def queueOutputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::OutputEvent )

			debugMsg( 4, "Queueing #{events.size} output events." )
			@queuedOutputEventsMutex.synchronize {
				@queuedOutputEvents += events
				changed( true ) unless @queuedOutputEvents.empty?
			}
			debugMsg( 5, "#{@queuedOutputEvents.size} output events now queued." )

			notify_observers( self, 'output' )
			return @queuedOutputEvents.size
		end


		### Equality -- returns true if the <tt>otherFilter</tt> is exactly the
		### same as the receiver.
		def ==( otherFilter )
			return self.equal?( otherFilter )
		end


		### Comparison -- Returns -1, 0, or 1 if the receiver sorts higher,
		### equal to, or lower than the <tt>otherFilter</tt> object,
		### respectively, according to its sort position.
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
			return events.flatten.compact
		end


		### Process the specified output events and return any which are
		### unhandled or new. Events which are returned will be injected into
		### the stream. Filter subclasses should override this method if they
		### wish to process output events.
		def handleOutputEvents( *events )
			@queuedOutputEventsMutex.synchronize {
				events += @queuedOutputEvents
				@queuedOutputEvents.clear
			}
			return events.flatten.compact
		end


		### Return a stringified description of the filter.
		def to_s
			"%s filter [%d]" % [ self.class.name, @sortPosition ]
		end



		#########
		protected
		#########

		### Set the finished flag to <tt>true</tt>.
		def finish
			@isFinished = true
		end


	end # class IOEventFilter
end # module MUES

