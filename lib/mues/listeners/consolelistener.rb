#!/usr/bin/ruby
# 
# This file contains the MUES::ConsoleListener class, a derivative of the
# MUES::Listener class for accepting connections on the console.
# 
# == Synopsis
# 
#	require 'mues/listener'
#
#   cl = MUES::Listener::create( 'console' )
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
require 'mues/listener'
require 'mues/filters/commandshell'

module MUES

	### A derivative of the MUES::Listener class for accepting connections on the console.
	class ConsoleListener < MUES::Listener ; implements MUES::Debuggable

		### Class constants

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		### Create a new ConsoleListener object.
		def initialize( name, parameters={} )
			@listenerHandler = nil

			# Flush input lines
			super( name, parameters, $stdin )
		end


		######
		public
		######

		### Listener callback: Create a new IOEventFilter for inclusion in a
		### User's IOEventStream upon connection (hitting <return>). IO will be
		### done using the given +reactor+ (an IO::Reactor object).
		def createOutputFilter( reactor )

			# Unregister io after saving the listener's callback, as we want to
			# have it to reinstall when the filter gets cleaned up.
			@listenerHandler = reactor.unregister( @io )

			# Flush the 'connect' input
			@io.read(1)

			reactorProxy = MUES::ReactorProxy::new( reactor, @io )
			filter = MUES::ConsoleOutputFilter::new( reactorProxy, self )
			filter.debugLevel = self.filterDebugLevel

			return filter
		end


		### Destroy the console filter and re-install the listener's callback
		### for incoming data.
		def releaseOutputFilter( reactor, filter )
			self.log.notice "Reregistering STDIN for the console listener."
			args = @listenerHandler[:events] + @listenerHandler[:args]
			reactor.register( @io, *args, &@listenerHandler[:handler] )
		end
	

		#########
		protected
		#########


	end # class ConsoleListener
end # module MUES

