#!/usr/bin/ruby
# 
# This file contains the MUES::TelnetListener class: A MUES::SocketListener
# derivative that listens on a TCP/IP socket for telnet connections.
# 
# == Synopsis
# 
#   require 'mues/Listener'
#   telnetListener = MUES::Listener::create( 'Telnet',
#                                            :bindPort => 23,
#                                            :bindAddr => '0.0.0.0' )
# 
# == Rcsid
# 
# $Id: telnetlistener.rb,v 1.3 2002/08/29 07:30:22 deveiant Exp $
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
		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: telnetlistener.rb,v 1.3 2002/08/29 07:30:22 deveiant Exp $

		### Create a new TelnetListener object.
		def initialize( name, parameters={} )
			super( name, parameters )

			# :TODO: Extract telnet filter options from parameters?
		end


		######
		public
		######

		### Listener callback: Create a new MUES::TelnetOutputFilter from the
		### client socket after calling #accept on the listener socket.
		def createOutputFilter( poll )
			clientSocket = @io.accept
			pollProxy = MUES::PollProxy::new( poll, clientSocket )
			return MUES::TelnetOutputFilter::new( clientSocket, pollProxy, self )
		end



		#########
		protected
		#########


	end # class TelnetListener
end # module MUES

