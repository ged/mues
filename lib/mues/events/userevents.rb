#!/usr/bin/ruby
# 
# This file contains a collection of user event classes for the
# MUES::Engine. User events are events which facilitate the interaction of
# user objects and the Engine.
# 
# == Synopsis
# 
#   require "mues/events/UserEvents"
# 
# == Rcsid
# 
# $Id: userevents.rb,v 1.10 2002/08/02 20:03:44 deveiant Exp $
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
require "mues/Exceptions"

require "mues/events/BaseClass"

module MUES

	autoload :IOEventStream, "mues/IOEventStream"

	###########################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	###########################################################################

	### Abstract user event class
	class UserEvent < Event ; implements MUES::AbstractClass

		include MUES::TypeCheckFunctions

		# The user object associated with the event
		attr_reader :user

		### Initialize a new user event with the specified target user. This
		### method should be called by derivates' initializers.
		def initialize( aUser )
			checkType( aUser, User )
			@user = aUser
			super()
		end

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

	### User login event class. This event is used by the MUES::LoginSession
	### class to indicate to the MUES::Engine that the target user has logged in
	### successfully.
	class UserLoginEvent < UserEvent

		# The MUES::IOEventStream that was used by the LoginSession.
		attr_reader	:stream

		# The finished login session
		attr_reader :loginSession

		### Returns a new UserLoginEvent with the specified target user,
		### IOEventStream, and LoginSession.
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

