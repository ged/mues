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
# $Id: consolelistener.rb,v 1.2 2002/08/02 20:03:43 deveiant Exp $
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
	class ConsoleListener < MUES::Listener

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: consolelistener.rb,v 1.2 2002/08/02 20:03:43 deveiant Exp $

		### Create a new ConsoleListener object.
		def initialize( name, parameters )
			@myCallback = nil

			# Flush input lines
			while $stdin.read( 4096 ) {}
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
			pollObj.unregister( @io )
			pollProxy = MUES::PollProxy::new( pollObj )
			return MUES::ConsoleOutputFilter::new( pollProxy )
		end

		### Destroy the console filter and re-install the listener's callback
		### for incoming data.
		def releaseOutputFilter( pollObj, filter )
			pollObj.register( $stdin
		end
	

		#########
		protected
		#########


	end # class ConsoleListener
end # module MUES

