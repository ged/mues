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
#	require 'mues/filters/eventdelegator'
#
#	delegator = MUES::EventDelegator::new( self )
#   delegator.queueOutputEvents( MUES::PromptEvent::new )
#
# == Rcsid
# 
# $Id: eventdelegator.rb,v 1.15 2003/10/13 04:02:14 deveiant Exp $
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

require 'sync'

require 'mues/object'
require 'mues/events'
require 'mues/exceptions'
require 'mues/filters/ioeventfilter'

module MUES

	class EventDelegator < MUES::IOEventFilter ; implements MUES::Debuggable

		include MUES::TypeCheckFunctions
		
		### Class constants
		Version = /([\d\.]+)/.match( %q{$Revision: 1.15 $} )[1]
		Rcsid = %q$Id: eventdelegator.rb,v 1.15 2003/10/13 04:02:14 deveiant Exp $

		DefaultSortPosition	= 600
		DefaultHandlers = {
			:input	=> :handleInputEvents,
			:output => :handleOutputEvents,
		}


		### Create and return a EventDelegator object for the given
		### <tt>delegate</tt>, which will be called through the specified
		### handlers, each of which can be a Method, Proc, String, Symbol,
		### <tt>false</tt>, or <tt>nil</tt>. A Method or a Proc will be used
		### as-is, a String or Symbol is used to look up a method on the
		### <tt>delegate</tt> object via #method(), <tt>false</tt> indicates
		### that no handler should be called for that type of event, and
		### <tt>nil</tt> indicates that the defaults should be used
		### (<tt>:handleInputEvents</tt> and <tt>:handleOutputEvents</tt>). When
		### events of the appropriate type are received, the specified handler
		### is called via the #call method, with one or more events as arguments: eg.,
		###
		###   handler.call( *events )
		###
		### At least one of the handlers must result in an object that responds
		### to the #call method.
		def initialize( delegate, inHandler=nil, outHandler=nil, sortPos=DefaultSortPosition )
			super( sortPos )

			@inputHandler = normalizeHandler( delegate, inHandler, "input" )
			@outputHandler = normalizeHandler( delegate, outHandler, "output" )
			@handlerMutex = Sync::new
				
			raise MUES::Exception, "No valid handlers found." unless
				@inputHandler || @outputHandler

			@delegate = delegate
			@connected = true
		end



		######
		public
		######

		### InputEvent handler.
		def handleInputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::InputEvent )
			
			@handlerMutex.synchronize( Sync::SH ) {
				events = super( *events )
				return events unless @connected
				events = @inputHandler.call( self, *events ) if @inputHandler
			}

			return events
		end


		### OutputEvent handler.
		def handleOutputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::OutputEvent )
			
			@handlerMutex.synchronize( Sync::SH ) {
				events = super( *events )
				return events unless @connected
				events = @outputHandler.call( self, *events ) if @outputHandler
			}

			return events
		end


		### Return a stringified description of the filter.
		def to_s
			"%s filter for %s [%d]" %
				[ self.class.name, @delegate.to_s, @sortPosition ]
		end


		### Disconnect the delegator from the delegate and set the filter's
		### state to 'finished'.
		def disconnect
			@handlerMutex.synchronize( Sync::EX ) {
				@connected = false
				@inputHandler = nil
				@outputHandler = nil
			}

			self.finish
		end



		#########
		protected
		#########

		### Given a delegate object, a handler object, and a direction
		### (input/output), normalize it into something that can be called via a
		### #call method, or nil. If it cannot be normalized, an exception is
		### #raised.
		def normalizeHandler( delegate, handler, direction )
			handler = DefaultHandlers[direction.intern] if
				handler.nil?

			case handler
			when false
				return false

			when Method, Proc
				return handler

			when Symbol, String
				unless delegate.respond_to?( handler )
					raise NoMethodError,
						"Delegate does not respond to the %s handler (%s)" %
						  [ direction, handler.to_s ],
						caller(2)
				end

				return delegate.method( handler )

			else
				raise TypeError, "Unknown %s handler type '%s'" %
					[ direction, handler.class.name ]
			end
		end
			


	end # class EventDelegator
end # module MUES
