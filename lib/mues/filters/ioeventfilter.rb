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



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/Debugging"
require "mues/Events"
require "mues/Exceptions"


module MUES
	class IOEventFilter < Object
		include Comparable
		include Debuggable
		include AbstractClass

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: ioeventfilter.rb,v 1.2 2001/05/14 12:26:47 deveiant Exp $
		DefaultSortPosition = 500

		### Class methods
		class << self

			### (CLASS) METHOD: defaultSortPosition
			### Returns the integer that indicates what order the filter should
			### naturally sort to
			def defaultSortPosition
				@@DefaultSortPosition
			end
		end # class << self


		### Initializer

		### (PROTECTED) METHOD: initialize( sort=nil )
		### Initialize the filter, optionally setting the sort position to
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


		#######################################################################
		###	P U B L I C   M E T H O D S
		#######################################################################
		public

		### Accessors
		attr_accessor	:sortPosition
		attr_reader		:queuedInputEvents, :queuedOutputEvents, :isFinished

		### METHOD: shutdown
		### Shut the filter down
		def shutdown
			_debugMsg( 1, "In shutdown." )
			@isFinished = true
			return @queuedInputEvents + @queuedOutputEvents
		end

		### METHOD: start
		### Start up the filter
		def start
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
			}
			_debugMsg( 2, "#{@queuedInputEvents.size} input events now queued." )

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
			}
			_debugMsg( 2, "#{@queuedOutputEvents.size} output events now queued." )

			return @queuedOutputEvents.size
		end

		### (OPERATOR) METHOD: <=>( anIOEventFilterObject )
		### Comparison -- Returns -1, 0, or 1 if the receiver sorts higher, equal
		### to, or lower than the specified object, respectively.
		def <=>( anObject )
			checkType( anObject, MUES::IOEventFilter )
			return @sortPosition <=> anObject.sortPosition
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

	end # class IOEventFilter
end # module MUES

