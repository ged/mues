#!/usr/bin/ruby
# 
# This file contains the MUES::ReactorProxy class, instances of which allow
# limited and simplified access to an IO::Reactor object.
# 
# == Synopsis
# 
#   require 'mues/reactorproxy'
#
#	proxy = MUES::ReactorProxy::new( reactor, ioObject )
#	proxy.register( :read, :write, &method(:reactorEventHandler) )
# 
# == Subversion ID
# 
# $Id$
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

require 'mues/object'


module MUES

	### Proxy class to allow limited access to an IO::Reactor object.
	class ReactorProxy < MUES::Object

		include MUES::TypeCheckFunctions
		
		### Class constants

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		### Instantiate and return a new ReactorProxy for the specified
		### <tt>reactor</tt> (a Reactor object) and ioObject (an IO object).
		def initialize( reactor, ioObject )
			checkType( reactor, IO::Reactor )
			checkType( ioObject, IO )

			@reactor = reactor
			@ioObject = ioObject
		end


		######
		public
		######

		### Register the specified <tt>callback</tt> (a Method or Proc
		### object) or <tt>block</tt> for the specified <tt>eventMask</tt>
		### (see the Reactor#register method for details)
		def register( *args, &block )
			return @reactor.register( @ioObject, *args, &block )
		end


		### Unregister any callbacks for the IO associated with the proxy.
		def unregister
			return @reactor.unregister( @ioObject )
		end


		### Returns true if the IO associated with the proxy is registered
		### with the Reactor object.
		def registered?
			return @reactor.handles.key?( @ioObject )
		end


		### Add the specified <tt>events</tt> to the proxied IO::Reactor
		### object's current event list for the IO associated with the
		### proxy.
		def enableEvents( *events )
			return @reactor.enableEvents( @ioObject, *events )
		end


		### Remove the specified <tt>events</tt> from the proxied reactor
		### object's current list of events to respond to for the IO associated
		### with the proxy.
		def disableEvents( *events )
			return @reactor.disableEvents( @ioObject, *events )
		end

	end # class ReactorProxy
end # module MUES

