#!/usr/bin/ruby
# 
# This is the default input event filter. It is included in every IOEventStream as
# a last-resort input event handler.
# 
# == Synopsis
# 
#   require 'mues/filters/defaultinputfilter'
# 
# == Rcsid
# 
# $Id: defaultinputfilter.rb,v 1.8 2003/10/13 04:02:14 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Alexis Lee <red@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require 'mues/filters/inputfilter'

module MUES

	### The default input filter class, a derivative of the MUES::InputFilter
	### class which is placed in every MUES::IOEventStream to catch events which
	### aren't processed by any other filter.
	class DefaultInputFilter < MUES::InputFilter

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.8 $ )[1]
		Rcsid = %q$Id: defaultinputfilter.rb,v 1.8 2003/10/13 04:02:14 deveiant Exp $
		DefaultSortPosition = 1000


		### Class attributes

		# Error message array.
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


		### Create and return a new default input filter.
		def initialize
			super
			@errorIndex = 0
		end


		### Handle the given <tt>events</tt> by creating an OutputEvent
		### containing an error message for each.
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


