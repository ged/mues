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
# Concrete derivatives of this class will probably be interested in providing
# implementations of one or more of the following operations:
#
# [<tt>createOutputFilter( <em>pollObject</em> )</tt>]
#   Called when the listener's IO object indicates it is readable, this method
#   is responsbible for doing any preparation work (eg., calling #accept on the
#   socket, etc.), and returning an appropriate MUES::IOEventFilter object. The
#   <tt>pollObject</tt> parameter is the Engine's Poll object, which the filter
#   can use to drive its own IO, perhaps through a MUES::PollProxy object.
#
# [<tt>releaseOutputFilter( <em>filter</em> )</tt>]
#   Called after a filter created by this listener indicates that its peer has
#   disconnected or that it has an error condition, this method is responsible
#   for returning any resources the filter has held to the system. The
#   <tt>filter</tt> argument is the disconnecting MUES::IOEventFilter object.
# 
# == Synopsis
#
#	require "mues/PollProxy"
#	require "mues/IOEventFilters"
# 
#   class MySocketListener < MUES::Listener
#
#       def createOutputFilter( poll )
#           clientSocket = self.io.accept
#			proxy = MUES::PollProxy::new( poll, clientSocket )
#			return MUES::MyOutputFilter::new( clientSocket, pollProxy )
#       end
#
#       def releaseOutputFilter( filter )
#           # no-op
#       end
#
#   end
# 
# == Rcsid
# 
# $Id: listener.rb,v 1.4 2002/09/12 11:48:03 deveiant Exp $
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
require 'mues/PollProxy'


module MUES

	### An abstract base class for listener objects.
	class Listener < MUES::Object; implements MUES::AbstractClass

		include MUES::FactoryMethods

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: listener.rb,v 1.4 2002/09/12 11:48:03 deveiant Exp $

		### Class methods

		### Return a list of directories to search for listener classes.
		def self.derivativeDirs
			["mues/listeners"]
		end


		### Create a new Listener object with the specified <tt>name</tt>,
		### optional <tt>parameters</tt> (a Hash), and <tt>io</tt> (an IO
		### object).
		def initialize( name, parameters={}, io=nil )
			@name		= name
			@parameters	= parameters
			@io			= io

			self.log.info( "Initialized a %s" % self.class.name )

			super()
			self.log.debug {"Returning from MUES::Listener initializer"}
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


		# Virtual methods required in derivatives
		abstract :createOutputFilter, :releaseOutputFilter


		### Return a human-readable version of the listener suitable for log
		### messages, etc.
		def to_s
			return "%s (a %s)" % [ self.name, self.class.name ]
		end


		#########
		protected
		#########
		
	end # class Listener
end # module MUES

