#!/usr/bin/ruby
###########################################################################
=begin

=IOEventFilter.rb

== Name

IOEventFilter - An abstract base I/O event filter class

== Synopsis

  require "mues/filters/IOEventFilter"

  class MyFilter < MUES::IOEventFilter
    @@SortDisposition = 750
    ...
  end

== Description

IOEventFilter is an abstract base class for filter objects in an
((<IOEventStream>)). The filters act on the contents of IOEvents, modifying
them, creating events based on them, changing their own internal state or the
state of an associated object based on them, or ignoring them, depending on the
task which the filter is supposed to accomplish.

The IOEventFilter class implements the Subject role of the Observer pattern, and
objects which observe it are notified when it has pending IOEvents.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "observer"

require "mues/Namespace"
require "mues/Events"
require "mues/Exceptions"


module MUES
	class IOEventFilter < Object ; implements Observable, Comparable, Debuggable, AbstractClass

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.8 $ )[1]
		Rcsid = %q$Id: ioeventfilter.rb,v 1.8 2001/09/26 13:24:31 deveiant Exp $
		DefaultSortPosition = 500

		### Initializer

		### METHOD: new( sort=nil )
		### Create a new filter, optionally setting the sort position to
		### the value specified.
		protected
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


		###################################################
		###	P U B L I C   M E T H O D S
		###################################################
		public

		### Accessors
		attr_accessor	:sortPosition
		attr_reader		:queuedInputEvents, :queuedOutputEvents, :isFinished
		alias :isFinished? :isFinished

		### METHOD: shutdown
		### Shut the filter down, returning any events which should be
		### dispatched on behalf of the filter.
		def shutdown
			_debugMsg( 1, "In shutdown." )
			@isFinished = true
			delete_observers()
			return []
		end

		### METHOD: start( streamObject )
		### Start up the filter for the specified stream. Returns true on success.
		def start( streamObject )
			add_observer( streamObject )
			true
		end

		### METHOD: stop( streamObject )
		### Stop the filter for the specified stream. Returns true on success.
		def stop( streamObject )
			delete_observer( streamObject )
			true
		end

		### METHOD: queueInputEvents( *events )
		### Add saved input events for this filter that will be injected into the
		### event stream on the next IO loop.
		def queueInputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::InputEvent )

			_debugMsg( 1, "Queueing #{events.size} input events." )
			@queuedInputEventsMutex.synchronize {
				@queuedInputEvents += events
				changed( true ) unless @queuedInputEvents.empty?
			}
			_debugMsg( 2, "#{@queuedInputEvents.size} input events now queued." )

			notify_observers( self, 'input' )
			return @queuedInputEvents.size
		end

		### METHOD: queueOutputEvents( *events )
		### Add saved output events for this filter that will be injected into the
		### event stream on the next IO loop.
		def queueOutputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::OutputEvent )

			_debugMsg( 1, "Queueing #{events.size} output events." )
			@queuedOutputEventsMutex.synchronize {
				@queuedOutputEvents += events
				changed( true ) unless @queuedOutputEvents.empty?
			}
			_debugMsg( 2, "#{@queuedOutputEvents.size} output events now queued." )

			notify_observers( self, 'output' )
			return @queuedOutputEvents.size
		end

		### (OPERATOR) METHOD: <=>( anIOEventFilterObject )
		### Comparison -- Returns -1, 0, or 1 if the receiver sorts higher, equal
		### to, or lower than the specified object, respectively.
		def <=>( anObject )
			checkType( anObject, MUES::IOEventFilter )
			return ( @sortPosition <=> anObject.sortPosition ).nonzero? ||
				@muesid <=> anObject.muesid
		end

		### (VIRTUAL) METHOD: handleInputEvents( *events )
		### Default filter method for input events
		def handleInputEvents( *events )
			@queuedInputEventsMutex.synchronize {
				events += @queuedInputEvents
				@queuedInputEvents.clear
			}
			return events.flatten
		end

		### (VIRTUAL) METHOD: handleOutputEvents( *events )
		### Default filter method for output events
		def handleOutputEvents( *events )
			events.flatten!

			@queuedOutputEventsMutex.synchronize {
				events += @queuedOutputEvents
				@queuedOutputEvents.clear
			}
			return events.flatten
		end

		### METHOD: to_s
		### Return a stringified description of the filter
		def to_s
			"%s filter [%d]" % [ self.class.name, @sortPosition ]
		end

	end # class IOEventFilter
end # module MUES

