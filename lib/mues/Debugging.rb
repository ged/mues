#!/usr/bin/ruby -w
###########################################################################

=begin 
=Debugging.rb

== Name

Debuggable - a mixin module for debugging methods

== Synopsis

  require "mues/debugging"

  class MyClass < Object
	include Debuggable

	def initialize
	  _debugMsg( 1, "Initializing..." )
	end
  end

== Description

This module is a mixin that can be used to add debugging facilities to objects
or classes.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

###########################################################################

module Debuggable

	### (MIXIN) METHOD: debugMsg( level, *messages )
	### Output the specified messages to STDERR if the debugging level for the
	### receiver is at ((|level|)) or higher.
	def debugMsg( level, *messages )
		raise TypeError, "Level must be a Fixnum, not a #{level.class.name}." unless
			level.is_a?( Fixnum )
		return unless debugged?( level )

		logMessage = messages.collect {|m| m.to_s}.join('')
		frame = caller(1)[0]
		if Thread.current != Thread.main then
			$stderr.puts "[Thread #{Thread.current.id}] #{frame}: #{logMessage}"
		else
			$stderr.puts "#{frame}: #{logMessage}"
		end

		$stderr.flush
	end
	alias :_debugMsg :debugMsg

	### (MIXIN) METHOD: debugLevel=( value )
	### Set the debugging level for the receiver to the specified
	### ((|level|)). The ((|level|)) may be a (({Fixnum})) between 0 and 5, or
	### (({true})) or (({false})). Setting the level to 0 or (({false})) turns
	### debugging off.
	def debugLevel=( value )
		case value
		when true
			@debugLevel = 1
		when false
			@debugLevel = 0
		when Numeric, String
			value = value.to_i
			value = 5 if value > 5
			value = 0 if value < 0
			@debugLevel = value
		else
			raise TypeError, "Cannot set debugging level to #{value.inspect} (#{value.class.name})"
		end
	end

	### (MIXIN) METHOD: debugLevel()
	### Return the debug level of the receiver as a (({Fixnum})).
	def debugLevel
		defined?( @debugLevel ) ? @debugLevel : 0
	end

	### (MIXIN) METHOD: debugged?
	### Return true if the receiver's debug level is >= 1.
	def debugged?( level=1 )
		debugLevel() >= level
	end

end
