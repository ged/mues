#!/usr/bin/ruby
# 
# This module is a collection of event classes for system-level events, and a
# mixin which provides a default event handler for dispatching events based on
# their class.
# 
# == Synopsis
# 
#   require "mues/Events"
# 
#   include MUES::Event::Handler
# 
#   event = MUES::EngineShutdownEvent.new
#   eventQueue.priorityEnqueue( event )
# 
# == Mixins
# 
# [<tt><b>MUES::Event::Handler</b></tt>]
#   A default event handler mixin. Including this module mixes in a
#   <tt>handleEvent</tt> method that does dynamic dispatch to methods in the
#   class that mixes it in. It will look for a method called
#   <tt>_handle</tt><em>EventClass</em><tt>()</tt>, where <tt>eventClass</tt> is
#   the class of the event to handle. If no explicit handler is found, each of
#   the event^s superclasses is tried as well. If no handler is defined for any
#   of the events, it tries to call <tt>_handleEvent()</tt>. If no handler is
#   found, a MUES::UnhandledEventError is raised.
# 
# == To Do
# 
# * Work priority into the class heirarchy so you can optionally pass a priority
#   to the constructor of any subclass.
# 
# == Rcsid
# 
# $Id: events.rb,v 1.8 2002/04/11 16:59:11 deveiant Exp $
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


require "mues/events/BaseClass"
require "mues/events/IOEvents"
require "mues/events/LoginSessionEvents"
require "mues/events/UserEvents"
require "mues/events/SystemEvents"
require "mues/events/EnvironmentEvents"

module MUES

	### Abstract base event class
	class Event

		### A default event handler mixin module. Including this module adds a
		### #handleEvent method to the including class/module.
		module Handler

			### Event dispatcher method. This method does dynamic dispatch to
			### class-specific event handler methods in the class that mixes it
			### in. It will look for a method called
			### <tt>_handle<<em>eventClass</em>>()</tt>, where
			### <tt><em>eventClass</em></tt> is the class of the event to
			### handle. If no explicit handler is found, each of the event's
			### superclasses is tried as well. If no handler is defined for any
			### of the events, it tries to call <tt>_handleEvent()</tt>. If no
			### handler is found, a MUES::UnhandledEventError is raised.
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

			##
			# Register <tt>handlerObject</tt> to receive events of the specified
			# <tt>eventClasses</tt> or any of their derivatives. See the docs for MUES::Event
			# for how to handle events.
			def registerHandlerForEvents( handlerObject, *eventClasses )
				checkResponse( handlerObject, "handleEvent" )

				eventClasses.each do |eventClass|
					eventClass.RegisterHandlers( handlerObject )
				end
			end

		end

	end # class Event
end #module MUES



