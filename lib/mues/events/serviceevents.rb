#!/usr/bin/ruby
# 
# This file contains event classes for interacting with MUES::Services.
# 
# == Synopsis
# 
#   
# 
# == Author
# 
# Michael Granger <ged@FaerieMUD.org>
# 
# Copyright (c) 2002 The FaerieMUD Consortium. All rights reserved.
# 
# This module is free software. You may use, modify, and/or redistribute this
# software under the terms of the Perl Artistic License. (See
# http://language.perl.com/misc/Artistic.html)
# 
# == Version
#
#  $Id: serviceevents.rb,v 1.3 2002/08/29 07:07:14 deveiant Exp $
# 

require "mues/Object"
require "mues/Exceptions"

require "mues/events/Event"

module MUES

	### Base ServiceEvent class
	class ServiceEvent < MUES::Event ; implements MUES::AbstractClass

		### Initialize a new ServiceEvent. Should be called from a
		### derivative's initializer.
		def initialize( serviceName ) # :notnew:
			super()
			@name = serviceName
		end

		######
		public
		######

		# The name of the service that should act on this event.
		attr_reader :name


		### Return the event as a string.
		def to_s
			return "%s: %s Service" % [ super(), @name.capitalize ]
		end

	end # class ServiceEvents



	### Adapter request event
	class GetServiceAdapterEvent < ServiceEvent

		### Create and return a new GetServiceAdapterEvent object with the
		### specified <tt>serviceName</tt> as its target, the specified
		### arguments, which will be passed as arguments to the adapter's
		### constructor, and the specified <tt>callback</tt> or
		### <tt>callbackBlock</tt>. If a <tt>callback</tt> object (a Method or
		### Proc object) is given, the <tt>callbackBlock</tt> argument is
		### ignored. At least one of the callbacks must be defined.
		def initialize( serviceName, args=[], callback=nil, &callbackBlock )
			super( serviceName )

			raise ArgumentError,
				"You must specify either an explicit callback method " +
				"or a callback block." unless callback || callbackBlock
			

			@args = args
			@callback = callback || callbackBlock
		end


		######
		public
		######

		# The array of arguments that should be passed to the adapter's
		# constructor.
		attr_reader :args

		# The callback (a Method or Proc object) to pass the new adapter to.
		attr_reader :callback

	end


end # module MUES

