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
# == Subversion ID
# 
# $Id$
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
require 'pluginfactory'

require 'mues/object'
require 'mues/reactorproxy'


module MUES

	### An abstract base class for listener objects.
	class Listener < MUES::Object; implements MUES::AbstractClass

		include PluginFactory

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# The default parameter hash for listeners
		DefaultParameters = {
			:filterDebug	=> 1,
			:questionnaire	=> {
				:name => 'login',
			}
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
		### optional <tt>params</tt> (a Hash), and <tt>io</tt> (an IO object).
		def initialize( name, params={}, io=nil )
			@name	= name
			@params	= DefaultParameters.merge( params, &MUES::HashMergeFunction )
			@io		= io

			@filterDebugLevel	= params[:filterDebug].to_i

		#	raise ArgumentError, "No questionnaire config given for %s" % self unless
		#		params.key?(:questionnaire)

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
		attr_reader :params
		alias_method :parameters, :params

		# The IO object associated with this listener.
		attr_reader :io

		# The debugging level that will be set on new filter created by this
		# listener
		attr_accessor :filterDebugLevel

		# Virtual methods required in derivatives
		abstract :createOutputFilter, :releaseOutputFilter


		### Halt the listener and accept no more clients.
		def stop
			@io = nil
		end


		### Create the initial set of filters for connections to this listener
		### and return them as an Array. This should consist of anything needed
		### for setup/login. By default, the MUES::Questionnaire specified in
		### the +questionnaire+ item of the config is loaded and returned as the
		### only initial filter, but this can be overridden by subclasses if you
		### don't want an interactive login for some reason.
		def getInitialFilters( filter )
			filters = []

			self.log.debug "Loading initial filters for %s: %p" %
				[ self, @params ]
			
			# Load the configured questionnaire
			if @params.key?( :questionnaire ) ||
				@params[:questionnaire].nil? ||
				@params[:questionnaire].empty? ||
				@params[:questionnaire][:name].nil? ||
				@params[:questionnaire][:name].empty? ||

				qconfig = @params[:questionnaire]
				self.log.debug "Loading questionnaire for %s" % self

				qnaire = MUES::Questionnaire::load( qconfig[:name], self.name )
				qconfig[:params].each {|k,v| qnaire.data[k] = v }
				qnaire.data[:filter] = filter
				qnaire.debugLevel = @filterDebugLevel
				self.log.debug "Loaded %p for %s" % [ qnaire, self ]

				filters << qnaire
			end

			return filters
		end


		### Return a human-readable version of the listener suitable for log
		### messages, etc.
		def to_s
			return "%s (a %s)" % [ self.name, self.class.name ]
		end


	end # class Listener
end # module MUES

