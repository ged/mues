#!/usr/bin/ruby
# 
# This file contains the MUES::Listener class: An abstract base class for
# "listener" objects. Instances of concrete derivatives of this class
# encapsulate the functionality of opening a "listening" IO object and then
# joining incoming connections on that IO object with an instance of
# MUES::IOEventFilter that is designed to service it.
#
# Instances of this class's derivatives are usually constructed by a
# MUES::Config::ListenersSection object.
# 
# == Synopsis
# 
#   class MyListener < MUES::Listener
#
#		def getListenerIO
#			...
#		end
#
#		def handleConnectionEvent( event )
#			...
#		end
#
#	end
# 
# == Rcsid
# 
# $Id: listener.rb,v 1.1 2002/07/07 18:31:05 deveiant Exp $
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

require 'mues'


module MUES

	### An abstract base class for listener objects.
	class Listener < MUES::Object

		include FactoryMethods

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: listener.rb,v 1.1 2002/07/07 18:31:05 deveiant Exp $

		### Create a new Listener object.
		def initialize( name, bindAddr='0.0.0.0', bindPort=2424 )
			@name = name
			@addr = bindAddr
			@port = bindPort
			@io = nil
		end


		######
		public
		######

		# An IO object bound to the listener, suitable for calling accept() on
		# for "incoming" connections.
		attr_reader :io

		### Abstract (virtual) methods
		abstract :accept


		#########
		protected
		#########


		
	end # class Listener
end # module MUES

