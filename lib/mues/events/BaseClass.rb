#!/usr/bin/ruby
#################################################################
=begin

=BaseClass.rb

== Name

BaseClass - An abstract base class for MUES events

== Synopsis

  require "mues/events/BaseClass"

  module MUES
    class MyEventType < Event
     :
    end
  end

== Description

This class is an abstract base class for MUES event classes.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "mues/Namespace"
require "mues/Exceptions"

module MUES

	### (ABSTRACT BASE) CLASS: Event < Object
	class Event < Object ; implements Debuggable, AbstractClass

		### Class constants
		MaxPriority		= 64
		MinPriority		= 1
		DefaultPriority	= (MaxPriority / 2).to_i

		### Class attributes
		@@Handlers = { Event => [] }

		### Class methods
		class << self

			### (STATIC) METHOD: RegisterHandlers( *handlers )
			### Register the specified objects as interested in events of the
			###		receiver class
			def RegisterHandlers( *handlers )
				checkEachResponse( handlers, "handleEvent" )

				### Add the handlers to the handlers for this class
				@@Handlers[ self ] |= handlers
				return @@Handlers[ self ].length
			end

			### (STATIC) METHOD: UnregisterHandlers( *handlers )
			### Unregister the specified objects as interested in events of the
			###		receiver class
			def UnregisterHandlers( *handlers )
				@@Handlers[ self ] -= handlers
				@@Handlers[ self ].length
			end

			### (STATIC) METHOD: GetHandlers
			### Return handlers for the specified class and its parents, most
			###		specific first
			def GetHandlers
				return self.ancestors.find_all { |klass| 
					klass <= Event
				}.collect { |klass|
					@@Handlers[ klass ]
				}.flatten.uniq
			end

			### (SINGLETON) METHOD: inherited( newSubclass )
			### Set up a handler array for each new subclass as it is created
			def inherited( newSubclass )
				@@Handlers[ newSubclass ] = []
			end
		end


		### Instance methods
		attr_reader		:creationTime, :priority

		### METHOD: initialize
		### Initialize a new event
		def initialize( priority=DefaultPriority )
			super()
			self.priority = priority
			@creationTime = Time.now
			_debugMsg( 1, "Initializing an #{self.class.name} at #{@creationTime} (priority=#{@priority})" )
		end

		### METHOD: priority=( priority )
		### Set the priority for this event
		def priority=( priority )
			checkType( priority, Integer )
			priority = MaxPriority if priority > MaxPriority
			priority = MinPriority if priority < MinPriority
			@priority = priority
		end

		### METHOD: <=>
		### Returns 1, 0, or -1 depending on the priority of the events specified.
		def <=>( otherEvent )
			checkType( otherEvent, Event )
			( @priority <=> otherEvent.priority ).nonzero? || @creationTime <=> otherEvent.creationTime
		end

		### METHOD: to_s
		### Stringify the event
		def to_s
			"%s: [pri %d] at %s" % [
				self.class.name,
				priority,
				creationTime.to_s
			]
		end

	end

end # module MUES

