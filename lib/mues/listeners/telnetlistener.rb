#!/usr/bin/ruby
# 
# This file contains the MUES::TelnetListener class: A MUES::SocketListener
# derivative that listens on a TCP/IP socket for telnet connections.
# 
# See MUES::SocketListener#initialize for valid configuration values.
#
# == Synopsis
# 
#   require 'mues/Listener'
#   telnetListener = MUES::Listener::create( 'Telnet',
#                                            'bind-port' => 23,
#                                            'bind-addr' => '0.0.0.0' )
# 
# == Rcsid
# 
# $Id: telnetlistener.rb,v 1.5 2003/09/12 04:32:20 deveiant Exp $
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

require 'mues/Exceptions'
require 'mues/listeners/SocketListener'
require 'mues/filters/TelnetOutputFilter'

module MUES

	### A MUES::Listener class that listens on a TCP/IP socket for incoming
	### telnet connections.
	class TelnetListener < MUES::SocketListener

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
		Rcsid = %q$Id: telnetlistener.rb,v 1.5 2003/09/12 04:32:20 deveiant Exp $

		### Create a new TelnetListener object. See
		### MUES::SocketListener#initialize for the list of valid
		### <tt>parameters</tt>.
		def initialize( name, parameters={} )
			super( name, parameters )

			# :TODO: Extract telnet filter options from parameters?
		end


		######
		public
		######

		### Listener callback: Create a new MUES::TelnetOutputFilter from the
		### client socket after calling #accept on the listener socket.
		def createOutputFilter( reactor )
			clientSocket = @io.accept
			reactorProxy = MUES::ReactorProxy::new( reactor, clientSocket )
			filter = MUES::TelnetOutputFilter::new( clientSocket, reactorProxy, self )
			filter.debugLevel = self.filterDebugLevel

			return filter
		end



		#########
		protected
		#########


	end # class TelnetListener
end # module MUES

