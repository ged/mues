#!/usr/bin/ruby
# 
# This file contains MUES::ClientOutputFilter, a MUES::IOEventFilter derivative
# used to process the I/O stream for a game client.
# 
# <strong><em>This class is currently just a placeholder</em></strong>
# 
# == Synopsis
# 
#   require 'mues/filters/clientoutputfilter'
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
# Please see the file COPYRIGHT for licensing details.
#

require 'mues/object'
require 'mues/filters/outputfilter'

module MUES

	### A derivative of the MUES::IOEventFilter class for processing IO for a
	### dedicated game client. <em>This class is currently just a
	### placeholder.</em>
	class ClientOutputFilter < MUES::OutputFilter

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# Sort order number (See MUES::IOEventFilter)
		DefaultSortPosition = 101

	end # class ClientOutputFilter
end # module MUES

