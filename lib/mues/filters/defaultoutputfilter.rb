#!/usr/bin/ruby
###########################################################################
=begin

=DefaultOutputFilter.rb

== Name

DefaultOutputFilter - default output event filter class

== Synopsis

  require "mues/filters/DefaultOutputFilter"

== Description

This is the default output event filter. It is included in every IOEventStream
as a last-resort output event handler.

== Classes
=== MUES::DefaultOutputFilter
==== Constructor

--- MUES::DefaultOutputFilter#new( historySize=10 )

    Instantiate and return a new default output filter object with the specified
    ((|historySize|)).

==== Public Methods

--- MUES::DefaultOutputFilter#history

    Return the array of output history.

--- MUES::DefaultOutputFilter#handleOutputEvents( *events )

    Handle output events. Appends output onto the history array.

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
	class DefaultOutputFilter < IOEventFilter

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: defaultoutputfilter.rb,v 1.3 2001/11/01 16:54:05 deveiant Exp $
		DefaultSortPosition = 0

		### Public methods
		public

		attr_accessor :history

		### METHOD: initialize( historySize=10 )
		def initialize( size=10 )
			super()
			@history = []
			@historySize = size
		end

		### METHOD: handleOutputEvents( *events )
		### Handle output events. Appends 
		def handleOutputEvents( *events )

			### Add event data to history
			@history = [] unless @history.is_a?( Array )
			@history += events.flatten.collect{|event| event.data}
			@history = @history[-@historySize..-1] if @history.length > @historySize
			[]
		end

	end

end
