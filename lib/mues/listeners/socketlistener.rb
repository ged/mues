#!/usr/bin/ruby
# 
# This file contains the MUES::SocketListener class: A MUES::Listener derivative
# for raw TCP/IP socket connections.
#
# == Synopsis
# 
#   use 'mues/Listener'
#
#   # Bind a listener to port 4848 on all interfaces
#   sockListener = MUES::Listener::create 'Socket',
#                                         'mues-socket',
#                                         'bind-port' => 4848,
#                                         'bind-addr' => '0.0.0.0',
#
#   # Bind to port 1248 on one IP, and use tcp_wrappers for access control.
#   sockListener = MUES::Listener::create 'Socket',
#                                         'mues-socket',
#                                         'bind-port'           => 1248,
#                                         'bind-addr'           => '10.2.1.13',
#                                         'use-wrappers'        => true,
#                                         'wrap-ident-lookup'   => true,
#                                         'wrap-ident-timeout'  => 15
# 
# == Rcsid
# 
# $Id: socketlistener.rb,v 1.7 2002/10/31 02:19:18 deveiant Exp $
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
		Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
		Rcsid = %q$Id: socketlistener.rb,v 1.7 2002/10/31 02:19:18 deveiant Exp $

		### Create a new SocketListener object with the specified
		### <tt>name</tt>. This listener understands the following
		### <tt>parameters</tt> in addition to those understood by
		### MUES::Listener:
		###
		### [<tt>bind-port</tt>]
		###   Specify the port the listening socket will be bound to. Defaults to port
		###   4848.
		### [<tt>bind-address</tt>]
		###   Specify the address which the listening socket will be bound to. The default
		###   of '0.0.0.0' means to bind all available interfaces.
		### [<tt>use-wrappers</tt>]
		###   If set to <tt>true</tt>, the listener will attempt to wrap the listening
		###   socket in a TCPWrapper object. This requires the 'tcpwrap' library
		###   (http://www.ruby-lang.org/en/raa-list.rhtml?name=ruby-tcpwrap).
		### [<tt>wrap-name</tt> (optional)]
		###   If <tt>use-wrappers</tt> is <tt>true</tt>, the value specified by this
		###   parameter is used as the "daemon process" name. The default is to use the
		###   <tt>name</tt> argument to MUES::Listener#new. See hosts_access(5) for more
		###   information. If <tt>use-wrappers</tt> is false, this parameter is ignored.
		### [<tt>wrap-ident-lookup</tt> (optional)]
		###   If both <tt>use-wrappers</tt> and this parameter are <tt>true</tt>, the
		###   access control lookup also requests RFC 1413 (ident) information from the
		###   connecting client. If <tt>use-wrappers</tt> is false, this parameter is
		###   ignored. This parameter defaults to <tt>false</tt>.
		### [<tt>wrap-ident-timeout</tt> (optional)]
		###   The number of seconds to wait for an RFC 1413 reply upon connection. The
		###   default timeout is 30.
		### [<tt>filter-debug</tt> (optional)]
		###	The debugging level set on filters created by this listener.
		def initialize( name, parameters={} )
			@io					= nil
			@name				= name
			@bindAddr			= parameters['bind-address'] || '0.0.0.0'
			@bindPort			= parameters['bind-port'] || 4848
			@wrappered			= false
			@wrapName			= parameters['wrap-name'] || name
			@wrapIdent			= parameters['wrap-ident'] || false
			@wrapIdentTimeout	= parameters['wrap-ident-timeout'] || 30

			# If the listener's configured to use tcp_wrappers, load the tcpwrap
			# library and set the wrappered flag.
			if parameters['use-wrapper']
				require 'tcpwrap'
				@wrappered			= true
			end

			self.log.info( "Creating a %s on %s:%d%s." %
						   [ self.class.name, @bindAddr, @bindPort,
							 @wrappered ? " (wrappered)" : ""] )

			# Create the listener socket, as pass it to the parent constructor
			# as the IO for this object.
			self.log.debug {"Creating socket..."}
			socket = TCPServer::new( @bindAddr, @bindPort )
			self.log.debug {"...done."}
			if self.wrappered?
				self.log.debug {"Wrapping socket..."}
				socket = TCPWrapper::new( @wrapName, socket, @wrapIdent, @wrapIdentTimeout )
				self.log.debug {"...done."}
			end

			self.log.debug {"Calling superclass constructor."}
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


		### Return a human-readable version of the listener suitable for log
		### messages, etc.
		def to_s
			"%s (a %s) on %s, port %d%s" % [
				self.name,
				self.class.name,
				self.bindAddr,
				self.bindPort,
				self.wrappered? ? " (wrappered)" : "",
			]
		end


		### Listener callback: Create and return a new MUES::SocketOutputFilter
		### from the client socket after calling #accept on the listener socket.
		def createOutputFilter( poll )
			clientSocket = @io.accept
			pollProxy = MUES::PollProxy::new( poll, clientSocket )
			filter = MUES::SocketOutputFilter::new( clientSocket, pollProxy, self )
			filter.debugLevel = self.filterDebugLevel

			return filter
		end


		### Listener callback: Dispose of the given (inactive) <tt>filter</tt>
		### (a MUES::SocketOutputFilter object) if need be.
		def releaseOutputFilter( pollObj, filter )
			self.log.notice "Filter %s (%s) released to %s" % 
				[ filter.muesid, filter.class.name, self.class.name ]
			return []
		end



		#########
		protected
		#########


	end # class SocketListener
end # module MUES

