#!/usr/bin/ruby
###########################################################################
=begin 

= Events.rb

== Name

MUES::Events - a collection of event classes for the MUES Engine

== Synopsis

  require "mues/Events"

  include MUES::Event::Handler

  event = MUES::EngineShutdownEvent.new
  eventQueue.priorityEnqueue( event )

== Description

This module is a collection of event classes for system-level events in the
FaerieMUD server. World events are subclasses of MUES::WorldEvent, and are
defined in the game object library.

== Mixins
=== MUES::Event::Handler

A default event handler mixin. Including this module mixes in a
(({handleEvent})) method that does dynamic dispatch to methods in the class that
mixes it in. It will look for a method called (({_handle*eventClass*()})), where
((|eventClass|)) is the class of the event to handle. If no explicit handler is
found, each of the event^s superclasses is tried as well. If no handler is
defined for any of the events, it tries to call (({_handleEvent()})). If no
handler is found, an ((<MUES::UnhandledEventError>)) is raised.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

== To Do

* Work priority into the class heirarchy so you can optionally pass a priority
  to the constructor of any subclass.

=end

###########################################################################

require "mues/events/BaseClass"
require "mues/events/IOEvents"
require "mues/events/LoginSessionEvents"
require "mues/events/UserEvents"
require "mues/events/SystemEvents"
require "mues/events/EnvironmentEvents"

module MUES
	class Event

		### A default event handler module. Including this module mixes in a
		### handleEvent() method that does dynamic dispatch to methods in the
		### class that mixes it in. It will look for a method called
		### '_handle<eventClass>()', where eventClass is the class of the event
		### to handle. If no explicit handler is found, each of the event's
		### superclasses is tried as well. If no handler is defined for any of
		### the events, it tries to call _handleEvent(). If no handler is found,
		### an UnhandledEventError is raised.
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

				### Now call the default handler if it defines one
				_debugMsg( 1, "Unable to handle the #{event.class.name}. Invoking the _handleEvent method." )
				return self._handleEvent( event ) if
					self.class.method_defined?( :_handleEvent )

				raise UnhandledEventError, "No handler defined for #{event.class.name}s"
			end

		end

	end # class Event
end #module MUES



