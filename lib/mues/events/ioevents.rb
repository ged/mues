#!/usr/bin/ruby
#
# This file contains event classes that are used for sending input or output to
# and from objects within the MUES::Engine. 
#
# The event classes defined in this file are:
#
# [MUES::IOEvent]
#	An abstract base class for Input/Output events.
#
# [MUES::OutputEvent]
#	An output event class.
#
# [MUES::InputEvent]
#	An input event class.
#
# [MUES::IOControlOutputEvent]
#	Abstract OutputEvent class for special output.
#
# [MUES::PromptEvent]
#	Output event class for prompting a user.
#
# [MUES::HiddenInputPromptEvent]
#	Prompt event class for prompting a user and hiding the resultant input.
#
# [MUES::DebugOutputEvent]
#	Output event class for events that carry debugging information.
#
# == Synopsis
#
#	require "mues/Mixins"
#   require "mues/Events"
#
#	include MUES::ServerFunctions
#
#   # Send a broadcast to all OutputEvent receivers
#   engine.dispatchEvents( OuputEvent.new "The server is shutting down." )
#
# == Rcsid
# 
# $Id: ioevents.rb,v 1.8 2002/08/02 20:03:44 deveiant Exp $
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

	### Abstract base class for Input/Output events.
	class IOEvent < Event ; implements MUES::AbstractClass

		### Initialize a new Input or OutputEvent. Should be called from a
		### derivative's initializer.
		def initialize( *args ) # :notnew:
			super()
			@data = args.collect {|m| m.to_s}.join('')
		end

		# The input or output data
		attr_accessor	:data

		### Return the event as a string.
		def to_s
			return "%s: %s" % [ super(), @data ]
		end
	end


	### Output event class. See MUES::IOEvent.
	class OutputEvent < IOEvent; end


	### Input event class. See MUES::IOEvent.
	class InputEvent < IOEvent; end


	### Abstract OutputEvent class for special output. This class adds an IO
	### control mode command to the regular OutputEvent which is used to control
	### the mode of display devices which have terminal controls suitable for
	### doing so. This is to support things like pagers, no-echo mode,
	### line-mode, etc.
	class IOControlOutputEvent < OutputEvent ; implements MUES::AbstractClass
	end


	### Output event class for prompting a user. A terminal client may just
	### print this prompt directly, while a graphical client may display a
	### dialog box and use the event's contents as the prompt message.
	class PromptEvent < IOControlOutputEvent

		### Create and return a new PromptEvent with the specified prompt
		### string.
		def initialize( arg="mues> " )
			super( arg )
		end
	end


	### Prompt event class for prompting a user and hiding the resultant
	### input. This is useful for prompting for secret or hidden input values
	### such as passwords or other data which should not be visible to a third
	### party. A telnet terminal may simply hide the input with the 'ECHO'
	### option, while a graphical client may wish to present a dialog which
	### displays asterisks for each character (or something).
	class HiddenInputPromptEvent < PromptEvent; end


	### Derivative of the OutputEvent class for events that carry debugging
	### information. <em>Currently unused.</em>
	class DebugOutputEvent < OutputEvent ; end


end # module MUES

