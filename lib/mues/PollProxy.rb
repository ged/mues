#!/usr/bin/ruby
# 
# This file contains the MUES::PollProxy class, instances of which allow limited
# and simplified access to a Poll object. This has the benefit of consolidating
# file-descriptor-based IO into a single poll loop which can be maintained by a
# single thread, instead of having a select loop per descriptor, each with its
# own thread.
# 
# == Synopsis
# 
#   require 'mues/PollProxy'
#
#	proxy = MUES::PollProxy::new( poll, ioObject )
#	proxy.register( Poll::WRNORM|Poll::RDNORM, method(:pollEventHandler) )
# 
# == Rcsid
# 
# $Id: PollProxy.rb,v 1.2 2002/08/02 20:03:44 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'mues/Object'


module MUES

	### Proxy class to allow limited access to a Poll object.
	class PollProxy < MUES::Object

		include MUES::TypeCheckFunctions
		
		### Instantiate and return a new PollProxy for the specified
		### <tt>poll</tt> (a Poll object) and ioObject (an IO object).
		def initialize( poll, ioObject )
			checkType( poll, Poll )
			checkType( ioObject, IO )

			@poll = poll
			@ioObject = ioObject
		end

		### Register the specified <tt>callback</tt> (a Method or Proc
		### object) or <tt>block</tt> for the specified <tt>eventMask</tt>
		### (see the Poll#register method for details)
		def register( eventMask, callback=nil, *args, &block )
			return @poll.register( @ioObject, eventMask, callback||block, *args )
		end

		### Unregister any callbacks for the IO associated with the proxy.
		def unregister
			return @poll.unregister( @ioObject )
		end

		### Returns true if the IO associated with the proxy is registered
		### with the Poll object.
		def registered?
			return @poll.registered?( @ioObject )
		end

		### Returns the event mask for the IO associated with the proxy.
		def mask
			return @poll.mask( @ioObject )
		end

		### Add (bitwise OR) the specified <tt>eventMask</tt> with the
		### proxied poll object's current mask for the IO associated with
		### the proxy. Returns the new mask.
		def addMask( eventMask )
			return @poll.addMask( @ioObject, eventMask )
		end

		### Remove (bitwise XOR) the specified <tt>eventMask</tt> from the
		### proxied poll object's current mask for the IO associated with
		### the proxy. Returns the new mask.
		def removeMask( eventMask )
			return @poll.removeMask( @ioObject, eventMask )
		end

	end # class PollProxy
end # module MUES

