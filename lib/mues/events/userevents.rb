#!/usr/bin/ruby
###########################################################################
=begin

=UserEvents.rb

== Name

UserEvents - A collection of user event classes

== Synopsis

  require "mues/events/UserEvents"

== Description

A collection of user event classes for the MUES Engine. User events are
events which facilitate the interaction between user objects and the Engine.

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

require "mues/events/BaseClass"

module MUES

	###########################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	###########################################################################

	### (ABSTRACT) CLASS: UserEvent < Event
	class UserEvent < Event ; implements AbstractClass
		autoload	:User, "mues/User"
		attr_reader :user

		### METHOD: new( aUser )
		### Returns a new user event with the specified target user
		def initialize( aUser )
			checkType( aUser, User )
			@user = aUser
			super()
		end

		### METHOD: to_s
		### Returns a stringified version of the event
		def to_s
			return "%s: %s" % [
				super(),
				@user.to_s
			]
		end
	end


	#######################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	#######################################################

	### CLASS: UserLoginEvent < UserEvent
	class UserLoginEvent < UserEvent

		autoload	'MUES::IOEventStream', "mues/IOEventStream"
		attr_reader	:stream, :loginSession

		### METHOD: new( aUser, anIOEventStream, aLoginSession )
		### Returns a new UserLoginEvent with the specified target user and
		### IOEventStream
		def initialize( aUser, anIOEventStream, aLoginSession )
			super( aUser )

			checkType( anIOEventStream, MUES::IOEventStream )
			checkType( aLoginSession, MUES::LoginSession )
			@stream = anIOEventStream
			@loginSession = aLoginSession
		end
	end

	### CLASS: UserIdleTimeoutEvent < UserEvent
	class UserIdleTimeoutEvent < UserEvent; end

	### CLASS: UserDisconnectEvent < UserEvent
	class UserDisconnectEvent < UserEvent; end

	### CLASS: UserLogoutEvent < UserEvent
	class UserLogoutEvent < UserEvent; end

	### CLASS: UserSaveEvent < UserEvent
	class UserSaveEvent < UserEvent; end

end # module MUES

