#!/usr/bin/ruby
#################################################################
=begin

=MacroFilter.rb

== Name

MacroFilter - a user-defined macro filter class

== Synopsis

  require "mues/filters/MacroFilter"
  filter = MUES::MacroFilter.new( aUser )

== Description

This is a class that provides expansion and definition facilities for
user-definable macros in an IOEventStream.

== Methods
=== Protected Instance Methods

--- initialize( user )

    Given a (({MUES::User})) object ((|user|)), initialize the macro table for
    the filter with the user^s preferences.

=== Public Instance Methods

--- handleInputEvents( *events )

    Handle the specified input events by searching for macro expansions and
    performing them on the data contained in the ((|events|)). Returns the given
    array with expansions performed.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Events"
require "mues/filters/IOEventFilter"

module MUES
	class MacroFilter < IOEventFilter ; implements Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: macrofilter.rb,v 1.4 2001/09/26 13:25:42 deveiant Exp $
		DefaultSortPosition = 650

		### Class variables
		@@MacroPrefix = ':'

		### Initializer

		### METHOD: initialize( user=MUES::User )
		### Initialize the macro filter with the macro table for the specified
		### ((|user|)), or a new one if the specified user doesn't yet have one.
		protected
		def initialize( user )
			super()
			checkType( user, MUES::User )

			@user		= user
			@macroTable = @user.preferences['macros'] || {}
		end

		### Public methods
		public

		### METHOD: handleInputEvents( *events=MUES::InputEvent )
		### Handle the specified input events by searching for macro expansions
		### and performing them on the data contained in the
		### ((|events|)). Returns the given array with expansions performed.
		def handleInputEvents( *events )
			events.flatten!
			events.compact!
			checkEachType( events, MUES::InputEvent )

			### For each event we get, search for patterns we know about,
			### running the substitution only once for each one we find.
			events.each {|e|
				alreadyMatched = {}

				if e.data =~ %r{^#{@@MacroPrefix}}

					@macroTable.each {|pattern,expansion|
						next unless e.data =~ pattern
						next if alreadyMatched[pattern]

						alreadyMatched[pattern] = true
						e.data.gsub!( pattern, expansion )
						retry
					}
				end
			}

			return *events
		end

	end # class MacroFilter
end # module MUES

