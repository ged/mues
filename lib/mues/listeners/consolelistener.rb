#!/usr/bin/ruby
# 
# This file contains the MUES::ConsoleListener class, a derivative of the
# MUES::Listener class for accepting connections on the console.
# 
# == Synopsis
# 
#	require 'mues/Listener'
#
#   cl = MUES::Listener::create( 'console' )
# 
# == Rcsid
# 
# $Id: consolelistener.rb,v 1.4 2002/10/26 19:05:10 deveiant Exp $
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
require 'mues/Listener'


module MUES

	### A derivative of the MUES::Listener class for accepting connections on the console.
	class ConsoleListener < MUES::Listener ; implements MUES::Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q{$Revision: 1.4 $} )[1]
		Rcsid = %q$Id: consolelistener.rb,v 1.4 2002/10/26 19:05:10 deveiant Exp $

		### Create a new ConsoleListener object.
		def initialize( name, parameters={} )
			@myCallback = nil
			@myMask = nil

			# Flush input lines
			super( name, parameters, $stdin )
		end


		######
		public
		######

		### Listener callback: Create a new IOEventFilter for inclusion in a
		### User's IOEventStream upon connection (hitting <return>).
		def createOutputFilter( pollObj )

			# Unregister io after saving the listener's callback, as we want to
			# have it to reinstall when the filter gets cleaned up.
			@myCallback = pollObj.callback( @io )
			@myMask = pollObj.mask( @io )
			pollObj.unregister( @io )

			# Flush the 'connect' input
			@io.read(1)

			pollProxy = MUES::PollProxy::new( pollObj, @io )
			listener = MUES::ConsoleOutputFilter::new( pollProxy, self )
			listener.debugLevel = self.filterDebugLevel

			return listener
		end


		### Destroy the console filter and re-install the listener's callback
		### for incoming data.
		def releaseOutputFilter( pollObj, filter )
			self.log.notice "Reregistering STDIN for the console listener."
			pollObj.register( $stdin, @myMask, @myCallback, self )
		end
	

		#########
		protected
		#########


	end # class ConsoleListener
end # module MUES

