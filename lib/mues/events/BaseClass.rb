#!/usr/bin/ruby
###########################################################################
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
###########################################################################

require "mues/Namespace"
require "mues/Exceptions"

module MUES

	### (ABSTRACT BASE) CLASS: Event < Object
	class Event < Object ; implements Debuggable, AbstractClass

		### MODULE: Event::Handler
		#  A useful default event handler module. Mixes in a handleEvent() method
		#  that does dynamic dispatch to methods in the class that mixes it in. It
		#  will look for a method called '_handle<eventClass>()', where eventClass
		#  is the class of the event to handle. If no explicit handler is found,
		#  each of the event's superclasses is tried as well. If no handler is
		#  defined for any of the events, it tries to call _handleUnknownEvent(). If
		#  no handler is found, an UnhandledEventError is raised.
		module Handler

			def handleEvent( event )
				raise TypeError, "argument (#{event.to_s}) is not an event"	unless
					event.is_a?( Event )
				_debugMsg( 1, "Handling a #{event.class.name} event." )

				methodName = ''

				### Search the event's class heirarchy for Event subclasses, and
				###	look up handler methods based on the class name
				event.class.ancestors.find_all {|klass| 
					klass <= Event
				}.each {|klass|
					eventType = klass.name.sub( /MUES::/, '' )
					_debugMsg( 2, "Checking for a _handle#{eventType} method..." )
					methodName = '_handle%s' % eventType
					if self.class.method_defined?( methodName )
						_debugMsg( 2, "   found #{methodName}." )
						return send( methodName, event )
					end
				}

				### Now call an UnknownEvent handler if it defines one
				_debugMsg( 1, "Unable to handle the #{event.class.name}. Invoking the _handleUnknownEvent method." )
				return self._handleUnknownEvent( event ) if
					self.class.method_defined?( :_handleUnknownEvent )

				raise UnhandledEventError, "No handler defined for #{event.class.name}s"
			end

		end

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

