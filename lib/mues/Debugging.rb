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
	  _debugMsg( "Initializing..." )
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

	def Debuggable.append_features( klass )
		klass.class_eval {
			@debugged = false
		}
		super
	end

	def _debugMsg( *messages )
		return nil unless debugged?
		level = messages[0].is_a?( Fixnum ) ? messages.shift : 5
		return unless debugged() >= level

		logMessage = messages.collect {|m| m.to_s}.join('')
		frame = caller(1)[0]
		if Thread.current != Thread.main then
			$stderr.puts "[Thread #{Thread.current.id}] #{frame}: #{logMessage}"
		else
			$stderr.puts "#{frame}: #{logMessage}"
		end
	end

	def debugged
		return false unless debugged?
		@debugged
	end

	def debugged=( value )
		@debugged = value
	end

	def debugged?
		defined?( @debugged ) && @debugged > 0
	end

end
