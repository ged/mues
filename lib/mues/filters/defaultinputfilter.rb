#!/usr/bin/ruby
###########################################################################
=begin

=DefaultInputFilter.rb

== Name

DefaultInputFilter - a default input filter class

== Synopsis

  require "mues/filters/DefaultInputFilter"

== Description

This is the default input event filter. It is included in every IOEventStream
as a last-resort input event handler.

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

		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: defaultinputfilter.rb,v 1.1 2001/03/29 02:34:27 deveiant Exp $

		@@DefaultSortPosition = 1000
		@@ErrorMessages = [ 
			"Huh?", 
			"I'm afraid I don't understand you.", 
			"What exactly am I supposed to do with '%s'?"
		]

		### METHOD: initialize
		def initialize
			super
			@errorIndex = 0
		end

		### METHOD: handleInputEvents( *events )
		def handleInputEvents( *events )
			events.flatten.each do |e|
				Thread.critical = true
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

			return []
		end

	end # class DefaultInputFilter
end # module MUES


