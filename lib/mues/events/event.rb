#!/usr/bin/ruby
# 
# This file contains the MUES::Event class -- an abstract base class for MUES
# events. All events in the MUES must inherit from this class in order to be
# recognized by the event dispatcher.
#
# You probably shouldn't require this file directly unless you're subclassing
# MUES::Event directly, as you can load all event classes with:
#
#   require 'mues/Events'
#
# Events in MUES are dispatched via the #dispatchEvents method of the Engine
# (the MUES::Engine instance) to an event queue (a MUES::EventQueue
# object). When a thread in the event queue's thread pool becomes available, the
# event is dispatched to any interested objects.
#
# In order to register an object's interest in a class of events, it must
# <em>register</em> with the event class in question. It can do so either by
# calling the <tt>RegisterHandlers()</tt> method on the event class with itself
# as the argument, or by calling the <tt>registerHandlerForEvents()</tt>
# function (which is a private global method defined in MUES::Object) with the
# event classes of interest as arguments.
#
# Objects which want to be able to receive events need to implement a public
# '<tt>handleEvent</tt>' method. You can mix in a default multiple-dispatch
# handler method by <tt>include</tt>ing the MUES::Event::Handler module.
#
# Event registration is hierarchal, so registering with one class also
# effectively registers the object with any events derived from it. So, for
# example, an object which wanted to get passed both MUES::InputEvents and
# MUES::OutputEvents would only need to register with MUES::IOEvent, as the
# former two inherit from the latter.
#
# For more about the finer details of event dispatch from the event queue, see
# the MUES::EventQueue documentation.
# 
# == Synopsis
# 
#   require "mues/Events"
# 
#   module MUES
#     class MyEvent < MUES::Event
#      :
#     end
#
#	  class MySubEvent < MyEventType
#	   :
#	  end
#   end
#
# 	class MyClass < MUES::Object
# 
#	  # Register all instances to recieve MyEvent and 
#	  # MySubEvent events:
# 	  def initialize
# 	    super
# 	    MyEvent.RegisterHandlers( self )
# 	  end
# 
# 	  def handleEvents( *events )
# 	    :
# 	  end
# 
# 	end
# 
#
# == Rcsid
# 
# $Id: event.rb,v 1.9 2002/08/01 01:14:08 deveiant Exp $
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

require "mues"
require "mues/Exceptions"

module MUES

	### Abstract base event class.
	class Event < Object ; implements MUES::Debuggable, MUES::AbstractClass, Comparable

		include MUES::TypeCheckFunctions

		### Class constants
		MaxPriority		= 64
		MinPriority		= 1
		DefaultPriority	= (MaxPriority / 2).to_i

		### Class attributes
		@@Handlers = { Event => [] }


		### Initialize a new event with the specified +priority+. This should be
		### called by the initializer of all derivate event classes.
		def initialize( priority=DefaultPriority ) # :notnew:
			super()
			self.priority = priority
			@creationTime = Time.now
			debugMsg( 1, "Initializing an #{self.class.name} at #{@creationTime} (priority=#{@priority})" )
		end


		### Class methods
		class << self

			### Register the specified objects as interested in events of the
			### receiver class
			def RegisterHandlers( *handlers )
				TypeCheckFunctions::checkEachResponse( handlers, "handleEvent" )

				### Add the handlers to the handlers for this class
				@@Handlers[ self ] |= handlers
				return @@Handlers[ self ].length
			end

			### Unregister the specified objects as interested in events of the
			### receiver class
			def UnregisterHandlers( *handlers )
				@@Handlers[ self ] -= handlers
				@@Handlers[ self ].length
			end

			### Return handlers for the specified class and its parents, most
			### specific first
			def GetHandlers
				return self.ancestors.find_all { |klass| 
					klass <= Event
				}.collect { |klass|
					@@Handlers[ klass ]
				}.flatten.uniq
			end

			### Set up a handler array for each new subclass as it is created
			def inherited( newSubclass )
				@@Handlers[ newSubclass ] = []
			end
		end


		######
		public
		######

		# The <tt>Time</tt> of the event's creation
		attr_reader :creationTime

		# The priority of the event (currently unused)
		attr_reader :priority


		### Set the priority for this event to +priority+, which should be a
		### Fixnum between 1 and MUES::Event::MaxPriority.
		def priority=( priority )
			checkType( priority, Integer )
			priority = MaxPriority if priority > MaxPriority
			priority = MinPriority if priority < MinPriority
			@priority = priority
		end

		### Comparison operator: Returns 1, 0, or -1 depending on the priority
		### of the events specified.
		def <=>( otherEvent )
			checkType( otherEvent, Event )
			( @priority <=> otherEvent.priority ).nonzero? || @creationTime <=> otherEvent.creationTime
		end

		### Return a stringified version of the event.
		def to_s
			"%s: [pri %d] at %s" % [
				self.class.name,
				priority,
				creationTime.to_s
			]
		end

	end

end # module MUES

