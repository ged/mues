#!/usr/bin/ruby -w
###########################################################################

=begin

= debugging.rb

== NAME

Debuggable - a mixin module for debugging methods

== SYNOPSIS

  require "mues/debugging"

  class MyClass < Object
	include Debuggable

	def initialize
	  _debugMsg( 1, "Initializing..." )
	end
  end

== DESCRIPTION

This module is a module of debugging mixins that can be used for debugging. And
stuff.

== AUTHOR

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

###########################################################################

module Debuggable

	def _debugMsg( *messages )
		level = messages[0].is_a?( Fixnum ) ? messages.shift : 5
		return unless debugged?( level )

		logMessage = messages.collect {|m| m.to_s}.join('')
		frame = caller(1)[0]
		if Thread.current != Thread.main then
			$stderr.puts "[Thread #{Thread.current.id}] #{frame}: #{logMessage}"
		else
			$stderr.puts "#{frame}: #{logMessage}"
		end
	end

	def debugLevel
		defined?( @debugLevel ) ? @debugLevel : 0
	end

	def debugLevel=( value )
		case value
		when true
			@debugLevel = 1
		when false
			@debugLevel = 0
		when Fixnum
			level = 5 if level > 5
			level = 0 if level < 0
			@debugLevel = level
		else
			raise TypeError, "Cannot set debugging level to #{value.to_s}"
		end
	end

	def debugged?( level=1 )
		debugLevel() >= level
	end

end
