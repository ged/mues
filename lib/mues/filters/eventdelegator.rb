#!/usr/bin/ruby
#
# This file contains the MUES::EventDelegator class, instances of which connect
# the stream of events in a MUES::IOEventStream to another object. It allows an
# object to interact with a stream and receive input and/or output events from
# it without having to be a filter itself.
#
# When the EventDelegator is created, it is given a <b>delegate</b>, which is
# the object that will be doing the IOEvent processing for it. The delegate
# should answer either the #handleInputEvents or #handleOutputEvents methods, or
# both. Each method will be called with the delegator as the first argument and
# any events that need to be handled as the remaining arguments, like so:
#
#	delegate.handleInputEvents( delegator, *events )
#
# Any events returned from this call will be passed along in the stream. You can
# inject your own events into the stream outside of an I/O cycle via the
# #queueOutputEvents and #queueInputEvents methods inherited from IOEventFilter,
# but the events passed to the handlers will include events which have been
# queued for the delegator.
#
# == Synopsis
#
#	require "mues/filters/EventDelegator"
#
#	delegator = MUES::EventDelegator::new( self )
#   delegator.queueOutputEvents( MUES::PromptEvent::new )
#
# == Rcsid
# 
# $Id: eventdelegator.rb,v 1.12 2002/09/28 12:55:03 deveiant Exp $
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

require "mues/Object"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

module MUES

	class EventDelegator < IOEventFilter ; implements MUES::Debuggable

		include MUES::TypeCheckFunctions
		
		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.12 $ )[1]
		Rcsid = %q$Id: eventdelegator.rb,v 1.12 2002/09/28 12:55:03 deveiant Exp $
		DefaultSortPosition = 600

		### Create and return a EventDelegator object for the given client. The
		### object must respond to the #handleInputEvents method.
		def initialize( delegate, sortPosition=DefaultSortPosition )
			super( sortPosition )

			unless delegate.respond_to?(:handleInputEvents) ||
					delegate.respond_to?(:handleOutputEvents)
				raise ArgumentError, "Delegate must respond to either :handleInputEvents, "
					":handleOutputEvents, or both"
			end

			@delegate = delegate
		end


		######
		public
		######

		### InputEvent handler.
		def handleInputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::InputEvent )
			
			events = super( *events )
			if @delegate.respond_to?( :handleInputEvents )
				events = @delegate.handleInputEvents( self, *events )
			end

			return events
		end


		### OutputEvent handler.
		def handleOutputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::OutputEvent )
			
			events = super( *events )
			if @delegate.respond_to?( :handleOutputEvents )
				events = @delegate.handleOutputEvents( self, *events )
			end

			return events
		end


	end # class EventDelegator
end # module MUES
