#!/usr/bin/ruby
###########################################################################
=begin

=PlayerEvents.rb

== Name

PlayerEvents - A collection of player event classes

== Synopsis

  require "mues/events/PlayerEvents"

== Description

A collection of player event classes for the MUES Engine. Player events are
events which facilitate the interaction between player objects and the Engine.

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
require "mues/Debugging"

require "mues/events/BaseClass"

module MUES

	###########################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	###########################################################################

	### (ABSTRACT) CLASS: PlayerEvent < Event
	class PlayerEvent < Event

		include		AbstractClass
		autoload	:Player, "mues/Player"
		attr_reader :player

		### METHOD: initialize( aPlayer )
		def initialize( aPlayer )
			checkType( aPlayer, Player )
			@player = aPlayer
			super()
		end

		### METHOD: to_s
		### Returns a stringified version of the event
		def to_s
			return "%s: %s" % [
				super(),
				@player.to_s
			]
		end
	end


	###########################################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	###########################################################################

	### CLASS: PlayerLoginEvent < PlayerEvent
	class PlayerLoginEvent < PlayerEvent; end

	### CLASS: PlayerIdleTimeoutEvent < PlayerEvent
	class PlayerIdleTimeoutEvent < PlayerEvent; end

	### CLASS: PlayerDisconnectEvent < PlayerEvent
	class PlayerDisconnectEvent < PlayerEvent; end

	### CLASS: PlayerLogoutEvent < PlayerEvent
	class PlayerLogoutEvent < PlayerEvent; end

	### CLASS: PlayerSaveEvent < PlayerEvent
	class PlayerSaveEvent < PlayerEvent; end

end # module MUES

