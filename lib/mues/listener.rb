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
# [<tt>createOutputFilter( <em>reactorObject</em> )</tt>]
#   Called when the listener's IO object indicates it is readable, this method
#   is responsbible for doing any preparation work (eg., calling #accept on the
#   socket, etc.), and returning an appropriate MUES::IOEventFilter object. The
#   <tt>reactorObject</tt> parameter is the Engine's IO::Reactor object, which
#   the filter can use to drive its own IO, perhaps through a MUES::ReactorProxy
#   object.
#
# [<tt>releaseOutputFilter( <em>filter</em> )</tt>]
#   Called after a filter created by this listener indicates that its peer has
#   disconnected or that it has an error condition, this method is responsible
#   for returning any resources the filter has held to the system. The
#   <tt>filter</tt> argument is the disconnecting MUES::IOEventFilter object.
# 
# == Synopsis
#
#	require 'mues/reactorproxy'
#	require 'mues/ioeventfilters'
# 
#   class MySocketListener < MUES::Listener
#
#       def createOutputFilter( reactor )
#           clientSocket = self.io.accept
#			proxy = MUES::ReactorProxy::new( reactor, clientSocket )
#			return MUES::MyOutputFilter::new( clientSocket, reactorProxy )
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
# $Id: listener.rb,v 1.12 2004/02/29 04:47:13 deveiant Exp $
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

require 'rbconfig'

require 'mues/object'
require 'mues/reactorproxy'


module MUES

	### An abstract base class for listener objects.
	class Listener < MUES::Object; implements MUES::AbstractClass

		include MUES::Factory

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.12 $} )[1]

		# CVS id tag 
		Rcsid = %q$Id: listener.rb,v 1.12 2004/02/29 04:47:13 deveiant Exp $

		# The default parameter hash for listeners
		DefaultParameters = {
			:filterDebug	=> 1,
			:questionnaire	=> 'login',
		}

		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		# The directories to search for derivative classes
		def self::derivativeDirs
			[ "mues/listeners" ]
		end



		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new Listener object with the specified <tt>name</tt>,
		### optional <tt>parameters</tt> (a Hash), and <tt>io</tt> (an IO
		### object).
		def initialize( name, parameters={}, io=nil )
			@name		= name
			@parameters	= Defaults.merge( parameters, &MUES::HashMergeFunction )
			@io			= io

			@filterDebugLevel 	= parameters[:filterDebug].to_i
			@loginQuestionnaire = parameters[:questionnaire]

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

		# The debugging level that will be set on new filter created by this
		# listener
		attr_accessor :filterDebugLevel

		# The name or instance of the MUES::Questionnaire to use for loading the
		# user for connections from this Listener.
		attr_accessor :loginQuestionnaire


		# Virtual methods required in derivatives
		abstract :createOutputFilter, :releaseOutputFilter


		### Halt the listener and accept no more clients.
		def stop
			@io = nil
		end


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

