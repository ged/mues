#!/usr/bin/ruby
# 
# This file contains the MUES::OutputFilter class, a derivative of
# MUES::IOEventFilter. It is an abstract base class for filters which provide IO
# abstraction for a user client of some sort.
# 
# == Synopsis
# 
#   require 'mues/filters/outputfilter'
#
#	module MUES
#		class MyOutputFilter < MUES::OutputFilter
#			...
#		end
#	end
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

require 'mues/filters/ioeventfilter'

module MUES

	### Instances.
	class OutputFilter < MUES::IOEventFilter ; implements MUES::AbstractClass

		### Class constants

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# Default filter sort order number (See MUES::IOEventFilter)
		DefaultSortPosition = 5

		### Create a new OutputFilter object with the specified
		### <tt>peerName</tt>, <tt>originListener</tt>, and
		### <tt>sortOrder</tt>. The <tt>peerName</tt> is a name associated with
		### the process to which the output from this filter is sent, eg., the
		### remote host, UNIX socket name, etc. The <tt>originListener</tt> is
		### an optional MUES::Listener object which will be notified when this
		### filter is halted (via MUES::Listener#releaseOutputFilter). Leaving
		### <tt>originListener</tt> unspecified means that no call will be
		### made. See MUES::IOEventFilter for information on the
		### <tt>sortOrder</tt> argument.
		def initialize( peerName, originListener=nil, sortOrder=DefaultSortPosition )
			@peerName = peerName.to_s
			@originListener = originListener

			super( sortOrder )
		end


		######
		public
		######

		# Virtual methods
		abstract :puts

		# The location of the entity on the other end of the filter, usually a
		# peer network address or file/socket path.
		attr_reader :peerName

		# The listener that created this filter
		attr_reader :originListener


		### Returns <tt>true</tt> if the filter's connection should be
		### considered 'local'; if it is 'local', it may be given special
		### capabilities such as connecting as the 'init-mode' admin user,
		### etc. It returns <tt>false</tt> by default.
		def isLocal?
			false
		end


		### Shut the filter down, severing the connection with the output
		### destination and calling any listener cleanup methods required.
		def stop( stream )
			results = []

			if @originListener
				self.log.debug "Returning a ListenerCleanupEvent for %s" % self.to_s
				results << MUES::ListenerCleanupEvent::new( @originListener, self )
			end
			
			results.push super( stream )
			return results.flatten
		end
		

	end # class OutputFilter
end # module MUES

