#!/usr/bin/ruby
# 
# This file contains MUES::MacroFilter, a derivative of the MUES::IOEventFilter
# class. It is a macro-expansion filter that can be used to set up custom
# shortcuts for long sequences of commands.
# 
# == Synopsis
# 
#   require 'mues/filters/macrofilter'
#   filter = MUES::MacroFilter.new( aUser )
# 
# == Rcsid
# 
# $Id: macrofilter.rb,v 1.9 2003/10/13 04:02:14 deveiant Exp $
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


require 'mues/object'
require 'mues/exceptions'
require 'mues/events'
require 'mues/filters/ioeventfilter'

module MUES

	### This is a class that provides expansion and definition facilities for
	### user-definable macros in an IOEventStream.
	class MacroFilter < IOEventFilter ; implements MUES::Debuggable

		include MUES::TypeCheckFunctions

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.9 $ )[1]
		Rcsid = %q$Id: macrofilter.rb,v 1.9 2003/10/13 04:02:14 deveiant Exp $
		DefaultSortPosition = 650

		### Class variables

		# The string prefix to associate with macro commands
		@@MacroPrefix = ':'


		### Initializer

		### Create and return a new macro filter for the specified <tt>user</tt>
		### (a MUES::User object). If the user's preferences has a Hash value
		### for the <tt>'macros'</tt> key, use the contents to initialize the
		### table. If not, start with an empty macro table.
		def initialize( user )
			super()
			checkType( user, MUES::User )

			@user		= user
			@macroPrefix= @user.preferences['macroPrefix'] || @@MacroPrefix
			@macroTable = @user.preferences['macros'] || {}
		end


		######
		public
		######

		# The string prefix to associate with macro commands
		attr_accessor	:macroPrefix


		### Prep the filter for shutdown.
		def stop( aStream )
			@user.preferences['macroPrefix'] = @macroPrefix
			@user.preferences['macros'] = @macroTable

			super( aStream )
		end


		### Handle the specified input events by searching for macro expansions
		### and performing them on the data contained in the
		### <tt>events</tt>. Returns the given array with expansions performed.
		def handleInputEvents( *events )
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

			return events
		end

	end # class MacroFilter
end # module MUES

