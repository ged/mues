#!/usr/bin/ruby
#
# This file contains the MUES::LoginProxy class which is a class that connects a
# MUES::LoginSession with a MUES::IOEventStream for the purposes of authentication
# and login for a connecting user. 
#
# == Synopsis
#
#	require "mues/filters/LoginProxy"
#
#	proxy = MUES::LoginProxy.new( self )
#   proxy.queueOutputEvents( PromptEvent.new("Login: ") )
#
# == Rcsid
# 
# $Id: LoginProxy.rb,v 1.10 2002/08/02 20:03:43 deveiant Exp $
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

	### A MUES::IOEventFilter class that acts as an IO proxy for a
	### MUES::LoginSession. The proxy acts as a blockade for input and output --
	### it only passes on events to and from the LoginSession until the user is
	### authenticated.
	class LoginProxy < IOEventFilter ; implements MUES::Debuggable

		include MUES::TypeCheckFunctions
		
		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.10 $ )[1]
		Rcsid = %q$Id: LoginProxy.rb,v 1.10 2002/08/02 20:03:43 deveiant Exp $
		DefaultSortPosition = 600

		### Create and return a LoginProxy object for the given +session+ (a
		### MUES::LoginSession object).
		def initialize( session )
			super()
			@session = session
		end


		######
		public
		######

		### InputEvent handler.
		def handleInputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::InputEvent )
			returnEvents = @session.handleInputEvents( *events )
			return returnEvents
		end


		### OutputEvent handler.
		def handleOutputEvents( *events )
			debugMsg( 1, "I have #{@queuedOutputEvents.length} pending output events." )
			ev = super()
			ev.flatten!
			debugMsg( 1, "Parent class's handleOutputEvents() returned #{ev.size} events." )

			return ev
		end


	end # class LoginProxy
end # module MUES
