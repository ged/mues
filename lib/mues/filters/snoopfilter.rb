#!/usr/bin/ruby
# 
# This file contains the MUES::SnoopFilter class, which is an IO snooping filter
# class derived from MUES::IOEventFilter.
#
# <em><strong>This class is currently just a non-functional
# placeholder.</strong></em>.
# 
# == Synopsis
# 
#   require "mues/filters/SnoopFilter"
# 
# == Rcsid
# 
# $Id: snoopfilter.rb,v 1.4 2002/08/02 20:03:43 deveiant Exp $
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

	### A "snoop" filter class derived from
	### MUES::IOEventFilter. <em><strong>This class is currently just a
	### non-functional placeholder.</strong></em>.
	class SnoopFilter < IOEventFilter

		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: snoopfilter.rb,v 1.4 2002/08/02 20:03:43 deveiant Exp $
		DefaultSortPosition = 300

	end # class SnoopFilter
end # module MUES



