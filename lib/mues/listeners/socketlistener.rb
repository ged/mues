#!/usr/bin/ruby
# 
# This file contains the MUES::SocketListener class: A MUES::Listener derivative
# for raw TCP/IP socket connections.
#
# This listener understands the following parameters in addition to those
# understood by MUES::Listener:
#
# [<tt>bindPort</tt>]
#   Specify the port the listening socket will be bound to. Defaults to port
#   4848.
# [<tt>bindAddr</tt>]
#   Specify the address which the listening socket will be bound to. The default
#   of '0.0.0.0' means to bind all available interfaces.
# [<tt>useWrappers</tt>]
#   If set to <tt>true</tt>, the listener will attempt to wrap the listening
#   socket in a TCPWrapper object. This requires the 'tcpwrap' library
#   (http://www.ruby-lang.org/en/raa-list.rhtml?name=ruby-tcpwrap).
# [<tt>wrapName</tt> (optional)]
#   If <tt>useWrappers</tt> is <tt>true</tt>, the value specified by this
#   parameter is used as the "daemon process" name. The default is to use the
#   <tt>name</tt> argument to MUES::Listener#new. See hosts_access(5) for more
#   information. If <tt>useWrappers</tt> is false, this parameter is ignored.
# [<tt>wrapIdentLookup</tt> (optional)]
#   If both <tt>useWrappers</tt> and this parameter are <tt>true</tt>, the
#   access control lookup also requests RFC 1413 (ident) information from the
#   connecting client. If <tt>useWrappers</tt> is false, this parameter is
#   ignored. This parameter defaults to <tt>false</tt>.
# [<tt>wrapIdentTimeout</tt> (optional)]
#   The number of seconds to wait for an RFC 1413 reply upon connection. The
#   default timeout is 30.
# 
# == Synopsis
# 
#   use 'mues/Listener'
#
#	# Bind a listener to port 4848 on all interfaces
#	sockListener = MUES::Listener::create 'Socket',
#										  'mues-socket',
#										  bindPort => 4848,
#										  bindAddr => '0.0.0.0',
#
#	# Do the same, but use tcp_wrappers for access control.
#	sockListener = MUES::Listener::create 'Socket',
#										  'mues-socket',
#										  bindPort => 4848,
#										  bindAddr => '0.0.0.0',
#										  useWrappers => true
# 
# == Rcsid
# 
# $Id: socketlistener.rb,v 1.1 2002/08/01 03:15:21 deveiant Exp $
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

require 'mues/Listener'
require 'mues/filters/SocketOutputFilter'
require 'socket'

module MUES

	### A listener class for raw TCP/IP socket connections.
	class SocketListener < MUES::Listener

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: socketlistener.rb,v 1.1 2002/08/01 03:15:21 deveiant Exp $

		### Create a new SocketListener object.
		def initialize( name, parameters={} )
			@io = nil
			@bindAddr			= parameters['bindAddr'] || '0.0.0.0'
			@bindPort			= parameters['bindPort'] || 4848
			@wrappered			= false
			@wrapName			= parameters['wrapName'] || @name
			@wrapIdent			= parameters['wrapIdent'] || false
			@wrapIdentTimeout	= parameters['wrapIdentTimeout'] || 30

			if parameters['use_wrapper']
				require 'tcpwrap'
				@wrappered			= true
			end

			self.log.info( "Creating a %s on %s:%d%s." %
						   [ self.class.name, @bindAddr, @bindPort,
							 @wrappered ? " (wrappered)" : ""] )

			# Create the listener socket, as pass it to the parent constructor
			# as the IO for this object.
			socket = TCPServer::new( @bindAddr, @bindPort )
			if self.wrappered?
				socket = TCPWrapper::new( @wrapName, socket, @wrapIdent, @wrapIdentTimeout )
			end

			super( name, parameters, socket )
		end


		######
		public
		######

		# The address the listener's socket is bound to
		attr_reader :bindAddr

		# The port the listener's socket is bound to
		attr_reader :bindPort

		# Flag to indicate whether or not this listener uses tcp_wrappers to
		# restrict connections. Alias: <tt>wrappered?</tt>
		attr_reader :wrappered
		alias :wrappered? :wrappered

		# The daemon name tcp_wrappers will use for the listener
		attr_reader :wrapName

		# Flag: should tcp_wrappers use ident lookups?
		attr_reader :wrapIdent

		# The number of seconds to wait for an ident lookup before timing out
		attr_reader :wrapIdentTimeout


		### Listener callback: Create a new MUES::SocketOutputFilter from the
		### client socket after calling #accept on the listener socket.
		def createOutputFilter( poll )
			clientSocket = @io.accept
			pollProxy = MUES::PollProxy::new( poll, clientSocket )
			return MUES::SocketOutputFilter::new( clientSocket, pollProxy )
		end


		### Listener callback: Dispose of the given <tt>filter</tt> if need be.
		def releaseOutputFilter( pollObj, filter )
			# no-op
		end



		#########
		protected
		#########


	end # class SocketListener
end # module MUES

