#!/usr/bin/ruby
###########################################################################
=begin

=LoginProxy.rb

== Name

LoginProxy - A login proxy class for IOEventStreams

== Synopsis

  require "mues/filters/LoginProxy"

== Description

Instances of this class are used in IOEventStreams to do authentication and
login for a user.

== Classes
=== MUES::LoginProxy
==== Constructor

--- MUES::LoginProxy.new( session )

    Initialize the LoginProxy object for the given ((|session|)) ( a
    ((<MUES::LoginSession>)) object).

==== Public Methods

--- MUES::LoginProxy#handleInputEvents( *events )

    Handle all input until the user has satisfied login requirements, then
    pass all input to upstream handlers.

--- MUES::LoginProxy#handleOutputEvents( *events )

    Handle all output events by ignoring their content and returning
    only those events that we have cached

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/Events"
require "mues/Exceptions"
require "mues/filters/IOEventFilter"

module MUES
	class LoginProxy < IOEventFilter ; implements Debuggable
		
		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: eventdelegator.rb,v 1.6 2001/11/01 17:42:39 deveiant Exp $
		DefaultSortPosition = 600

		### (PROTECTED) METHOD: initialize( session )
		### Initialize the LoginProxy object for the given LoginSession.
		def initialize( session )
			super()
			@session = session
		end

		### Public methods
		public

		### METHOD: handleInputEvents( *events )
		### Handle all input until the user has satisfied login requirements, then
		### pass all input to upstream handlers.
		def handleInputEvents( *events )
			events.flatten!
			checkEachType( events, MUES::InputEvent )
			returnEvents = @session.handleInputEvents( *events )
			return returnEvents
		end


		### METHOD: handleOutputEvents( *events )
		### Handle all output events by ignoring their content and returning
		### only those events that we have cached
		def handleOutputEvents( *events )
			_debugMsg( 1, "I have #{@queuedOutputEvents.length} pending output events." )
			ev = super()
			ev.flatten!
			_debugMsg( 1, "Parent class's handleOutputEvents() returned #{ev.size} events." )

			return ev
		end


	end # class LoginProxy
end # module MUES
