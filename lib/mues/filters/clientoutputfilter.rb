#!/usr/bin/ruby
# 
# This file contains MUES::ClientOutputFilter, a MUES::IOEventFilter derivative
# used to process the I/O stream for a game client.
# 
# <strong><em>This class is currently just a placeholder</em></strong>
# 
# == Synopsis
# 
#   require "mues/filters/ClientOutputFilter"
# 
# == Rcsid
# 
# $Id: clientoutputfilter.rb,v 1.5 2002/08/02 20:03:43 deveiant Exp $
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

require "mues/Object"
require "mues/filters/IOEventFilter"

module MUES

	### A derivative of the MUES::IOEventFilter class for processing IO for a
	### dedicated game client. <em>This class is currently just a
	### placeholder.</em>
	class ClientOutputFilter < IOEventFilter

		Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
		Rcsid = %q$Id: clientoutputfilter.rb,v 1.5 2002/08/02 20:03:43 deveiant Exp $
		DefaultSortPosition = 101

	end # class ClientOutputFilter
end # module MUES

