#!/usr/bin/ruby
# 
# This module is a collection of event classes for system-level (as opposed to
# environment-level) events, and a mixin which provides default methods for
# objects which wish to be event handlers.
# 
# == Synopsis
# 
#   require "mues/Events"
#	require "mues/Mixins"
# 
#   include MUES::Event::Handler
#	include MUES::ServerFunctions
# 
#   event = MUES::EngineShutdownEvent::new
#	event.priority = MUES::Event::MaxPriority
#   dispatchEvent( event )
# 
# == Mixins
# 
# [<tt><b>MUES::Event::Handler</b></tt>]
#   A default event handler mixin. Including this module mixes in a
#   <tt>handleEvent</tt> method that does dynamic dispatch to methods in the
#   class that mixes it in. It will look for a method called
#   <tt>handle</tt><em>EventClass</em><tt>()</tt>, where <tt>eventClass</tt> is
#   the class of the event to handle. If no explicit handler is found, each of
#   the event^s superclasses is tried as well. If no handler is defined for any
#   of the events, it tries to call <tt>handleEvent()</tt>. If no handler is
#   found, a MUES::UnhandledEventError is raised.
# 
# == To Do
# 
# * Work priority into the class heirarchy so you can optionally pass a priority
#   to the constructor of any subclass.
# 
# == Rcsid
# 
# $Id: events.rb,v 1.16 2003/05/12 18:41:29 deveiant Exp $
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


require "mues/events/Event"
require "mues/events/PrivilegedEvent"
require "mues/events/IOEvents"
require "mues/events/LoginSessionEvents"
require "mues/events/UserEvents"
require "mues/events/SystemEvents"
require "mues/events/EnvironmentEvents"
require "mues/events/ServiceEvents"
require "mues/events/CommandEvents"

module MUES

	### Abstract base event class
	class Event

		### A default event handler mixin module. Including this module adds
		### methods to the including class/module that are useful for an object
		### which wishes to handle one or more event types.
		module Handler

			include MUES::TypeCheckFunctions, MUES::Debuggable

			### Event dispatcher method. This method does dynamic dispatch to
			### class-specific event handler methods in the class that mixes it
			### in. It will look for a method called
			### <tt>handle<<em>eventClass</em>>()</tt>, where
			### <tt><em>eventClass</em></tt> is the class of the event to
			### handle. If no explicit handler is found, each of the event's
			### superclasses is tried as well. If no handler is defined for any
			### of the events, it tries to call <tt>handleAnyEvent()</tt>. If no
			### handler is found, a MUES::UnhandledEventError is raised.
			def handleEvent( event )
				raise TypeError, "argument (#{event.to_s}) is not an event"	unless
					event.is_a?( Event )
				debugMsg( 1, "Handling a #{event.class.name} event." )

				methodName = ''

				# Search the event's class heirarchy for Event subclasses, and
				# look up handler methods based on the class name
				event.class.ancestors.find_all {|klass| 
					klass <= Event
				}.each {|klass|
					eventType = klass.name.sub( /MUES::/, '' )
					debugMsg( 2, "Checking for a handle#{eventType} method..." )
					methodName = 'handle%s' % eventType
					if self.respond_to?( methodName )
						debugMsg( 2, "   found #{methodName}." )
						return send( methodName, event )
					end
				}

				### Now call the default handler if it defines one
				debugMsg( 1, "Unable to handle the #{event.class.name}. Invoking the handleEvent method." )
				return self.handleAnyEvent( event ) if
					self.respond_to?( :handleAnyEvent )

				raise UnhandledEventError, "No handler defined for #{event.class.name}s"
			end


			### Register <tt>handlerObject</tt> to receive events of the
			### specified <tt>eventClasses</tt> or any of their derivatives. See
			### the docs for MUES::Event for how to handle events.
			def registerHandlerForEvents( handlerObject, *eventClasses )
				checkResponse( handlerObject, "handleEvent" )

				eventClasses.each do |eventClass|
					eventClass.registerHandlers( handlerObject )
				end
			end


			### Unregister <tt>handlerObject</tt> as a handler for the specified
			### <tt>eventClasses</tt>, or all event classes if no classes are
			### specified.
			def unregisterHandlerForEvents( handlerObject, *eventClasses )
				eventClasses = MUES::Event::getEventClasses if eventClasses.empty?
				eventClasses.each {|eventClass|
					eventClass.unregisterHandlers( handlerObject )
				}
			end

		end

	end # class Event
end #module MUES



