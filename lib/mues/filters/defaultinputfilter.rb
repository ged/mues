#!/usr/bin/ruby
###########################################################################
=begin

=DefaultInputFilter.rb

== Name

DefaultInputFilter - a default input filter class

== Synopsis

  require "mues/filters/DefaultInputFilter"

== Description

This is the default input event filter. It is included in every IOEventStream as
a last-resort input event handler.

== Classes
=== MUES::DefaultInputFilter
==== Public Methods

--- MUES::DefaultInputFilter#initialize

    Initialize the filter.

--- MUES::DefaultInputFilter#handleInputEvents( *events )

    Handle the given ((|events|)) by creating an OutputEvent containing an error
	message for each.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/filters/IOEventFilter"

module MUES
	class DefaultInputFilter < IOEventFilter

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: defaultinputfilter.rb,v 1.4 2001/12/07 17:43:39 red Exp $
		DefaultSortPosition = 1000

		### Class attributes
		@@ErrorMessages = [ 
			"Huh?", 
			"Sorry, could you rephrase that?",
			"My English is not always as good as it should be.",
			"Could not parse '%s'.",
			"I'm afraid I don't understand you.", 
			"What exactly am I supposed to do with '%s'?",
			"Hmmm... I'm not sure I know how to '%s'.",
			"%s: Command not found."
		]

		### METHOD: initialize
		### Initialize the input filter
		def initialize
			super
			@errorIndex = 0
		end

		### METHOD: handleInputEvents( *events )
		### Handle the given ((|events|)) by creating an OutputEvent containing
		### an error message for each.
		def handleInputEvents( *events )
			events.flatten.each do |e|
				Thread.critical = true
				if e.data =~ /\w/
					begin
						msg = e.data
						@errorIndex += 1
						@errorIndex = 0 if @errorIndex > @@ErrorMessages.length - 1

						errmsg = @@ErrorMessages[ @errorIndex ] % msg
						queueOutputEvents( OutputEvent.new(errmsg + "\n") )
					ensure
						Thread.critical = false
					end
				end
			end

			return []
		end

	end # class DefaultInputFilter
end # module MUES


