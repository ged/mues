#!/usr/bin/ruby
# 
# This file contains the MUES::SnoopFilter class, instances of which are filters
# which can be used to monitor and/or inject events into one stream from
# another.
# 
# == Synopsis
# 
#   require "mues/filters/SnoopFilter"
# 
# == Rcsid
# 
# $Id: snoopfilter.rb,v 1.5 2002/10/31 02:18:47 deveiant Exp $
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

require "mues/Mixins"
require "mues/Object"
require "mues/filters/IOEventFilter"
require "mues/filters/EventDelegator"

module MUES

	### A "snoop" filter class derived from MUES::IOEventFilter.
	class SnoopFilter < MUES::IOEventFilter

		include MUES::TypeCheckFunctions

		### Class constants
		Version = /([\d\.]+)/.match( %q{$Revision: 1.5 $} )[1]
		Rcsid = %q$Id: snoopfilter.rb,v 1.5 2002/10/31 02:18:47 deveiant Exp $

		KeySigil = '@'
		DefaultSortPosition = 300
		DefaultTargetPosition = 299


		### Create and return a SnoopFilter object that will monitor events from
		### and inject events into the given <tt>targetStream</tt>, which must
		### be a MUES::IOEventStream or deriviative. It will be identified to
		### the snooping stream by the specified key, which is used to recognize
		### input events bound for the target stream, as well as a prefix when
		### displaying them. The specified <tt>user</tt> will be used to build a
		### notification message that is sent to the target stream upon
		### activation. If <tt>silent</tt> is <tt>true</tt> no notification will
		### be sent.
		def initialize( targetUser, snoopingUser, silent=false,
					    sortPosition=DefaultSortPosition, targetPosition=DefaultTargetPosition )
			checkType( targetUser, MUES::User )
			checkType( snoopingUser, MUES::User )

			super( sortPosition )

			delegator = MUES::EventDelegator::new self,
				:handleTargetInput, :handleTargetOutput, targetPosition

			@targetUser		= targetUser
			@snoopingUser	= snoopingUser
			@silent			= silent
			@delegator		= delegator
			@snoopingUser	= snoopingUser

			# Set the 'key' and the Regexp to match it as well.
			@key = KeySigil + targetUser.username
			@keyPattern = /^#{@key}/o

			@started = false
		end


		######
		public
		######

		# If false, the filter will inject notifying events into the target
		# stream when it connects.
		attr_accessor :silent
		alias_method :silent?, :silent

		# The user being snooped
		attr_reader :targetUser

		# The user doing the snooping
		attr_reader :snoopingUser


		### Return a stringified description of the filter.
		def to_s
			"%s on %s for %s [%d]" % [
				self.class.name,
				@targetUser.username,
				@snoopingUser.username,
				@sortPosition
			]
		end


		### Start the filter and its associated event delegator
		def start( stream )
			super( stream )

			@targetUser.ioEventStream.addFilters( @delegator )

			# Send the notification to the target stream via the delegator
			# unless we're running in silent mode.
			unless @silent
				notice = MUES::OutputEvent::new "\n[Snoop connection from %s]\n\n" %
					@snoopingUser.to_s
				@delegator.queueOutputEvents( notice )
			end
		end


		### Stop the filter and disconnect the associated event delegator
		def stop( stream )
			# Send the notification to the target stream via the delegator
			# unless we're running in silent mode.
			unless @silent
				notice = MUES::OutputEvent::new "\n[Snoop connection from %s closed]\n\n" %
					@snoopingUser.to_s
				@delegator.queueOutputEvents( notice )
			end

			# Disconnect and let the target stream do the cleanup
			@delegator.disconnect
			super( stream )
		end


		### Local stream InputEvent handler.
		def handleInputEvents( *events )
			return events unless @started
			events.flatten!
			checkEachType( events, MUES::InputEvent )
			
			# Get queued events from the parent handler
			events = super( *events )
			results = []

			# Iterate over events, adding ones that don't match the key pattern
			# to the results array, and redirecting those that do after removing
			# the key pattern from their data.
			events.each {|event|
				results.push( event ) unless @keyPattern.match( event.data )

				event.data.gsub!( keyPattern, '' ).trim!
				@delegator.queueInputEvents( event )
			}

			return results
		end


		### Remote stream InputEvent handler
		def handleTargetInput( delegator, *events )
			copiedEvents = []

			events.each {|event|

				# Copy the input event's data into an output event
				copyEvent = MUES::OutputEvent::new
				copyEvent.data = "\n%s [Input]: %s\n" % [ @key, event.data ]
				copiedEvents.push( copyEvent )
			}

			queueOutputEvents( *copiedEvents )
			return events
		end
		

		### Remote stream OutputEvent handler
		def handleTargetOutput( delegator, *events )
			copiedEvents = []

			events.each {|event|

				# Skip prompts and other terminal control events
				next if event.kind_of?( MUES::IOControlOutputEvent )

				# Copy the event's data into a new output event
				copyEvent = MUES::OutputEvent::new
				copyEvent.data = "\n%s [Output]: %s" % [ @key, event.data ]
				copiedEvents.push( copyEvent )
			}

			queueOutputEvents( *copiedEvents )
			return events
		end
		

	end # class SnoopFilter
end # module MUES



