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
# Concrete derivatives of this class must provide implementations of the
# following operations:
#
# [<tt>onConnect( <em>event</em> )</tt>]
#   Called when the listener's IO object indicates it is readable. This method
#   is responsbible for doing any preparation work (eg., calling #accept on the
#   socket, etc.), and returning a MUES::IOEventFilter object that is suitable
#   for constructing input events and handling output events for a connecting
#   client IO object, such as MUES::SocketOutputFilter or
#   MUES::ConsoleOutputFilter. The <tt>event</tt> parameter is the
#   MUES::ListenerConnectEvent that was generated to indicate the incoming
#   connection.
#
# [<tt>onDisconnect( <em>filter</em> )</tt>]
#   Called after a filter created by this listener indicates it has an error
#   condition or that its peer has disconnected, this method is responsible for
#   returning any resources it has held for the filter to the system. The
#   <tt>filter</tt> argument is the disconnecting MUES::IOEventFilter object.
# 
# == Synopsis
# 
#   class MyListener < MUES::Listener
#
#       def getIoObject
#           ...
#       end
#
#       def onConnect( event )
#           ...
#       end
#
#       def onDisconnect( filter, poll )
#           ...
#       end
#
#   end
# 
# == Rcsid
# 
# $Id: listener.rb,v 1.2 2002/08/01 02:49:32 deveiant Exp $
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
require 'mues/PollProxy'


module MUES

	### An abstract base class for listener objects.
	class Listener < MUES::Object; implements MUES::AbstractClass

		include MUES::FactoryMethods

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: listener.rb,v 1.2 2002/08/01 02:49:32 deveiant Exp $

		### Class methods

		### Return a list of directories to search for listener classes.
		def self.derivativeDirs
			["listeners"]
		end


		### Return an Array of listeners as configured by the specified
		### <tt>config</tt> (a MUES::Config object).
		def self.createFromConfig( config )
			return config.engine.listeners.collect {|name,lconfig|
				self.create( lconfig['class'], name, lconfig['parameters'] )
			}
		end


		### Create a new Listener object with the specified <tt>name</tt>,
		### optional <tt>parameters</tt> (a Hash), and <tt>io</tt> (an IO
		### object).
		def initialize( name, parameters={}, io=nil )
			@name		= name
			@parameters	= parameters
			@io			= io

			super()
		end


		######
		public
		######

		# The name of the listener, as it appears in logs and human-readable
		# lists.
		attr_reader :name

		# The Hash of parameters the listener was given at instantiation for
		# listener-specific configuration
		attr_reader :parameters

		# The IO object associated with this listener.
		attr_reader :io


		### Abstract (virtual) methods
		abstract :onConnect, :onDisconnect


		### Return a human-readable version of the listener suitable for log
		### messages, etc.
		def to_s
			return "%s (%s)" % [ self.class.name, self.name ]
		end

		#########
		protected
		#########
		
	end # class Listener
end # module MUES

