#!/usr/bin/ruby
# 
# This file contains the MUES::InputFilter class, a derivative of
# MUES::IOEventFilter. MUES::InputFilter is a base class for filters which are
# primarily concerned with receiving input from remote users, and so are likely
# to be responsible for parsing commands, executing actions based on user input,
# etc.
#
# Filters derived from this class should typically have a sort position (see the
# MUES::IOEventFilter docs) of 750 or higher.
# 
# == Synopsis
# 
#   require 'mues/filters/inputfilter'
#
#	module MUES
#		class MyInputFilter < MUES::InputFilter
#			...
#		end
#	end
# 
# == Rcsid
# 
# $Id: inputfilter.rb,v 1.2 2003/10/13 04:02:14 deveiant Exp $
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

	### a base class for filters which provide IO abstraction for one or more MUES subsystems.
	class InputFilter < MUES::IOEventFilter

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: inputfilter.rb,v 1.2 2003/10/13 04:02:14 deveiant Exp $
		DefaultSortPosition = 995


		######
		public
		######

		# Input handlers must at least override the input event handler.
		abstract :handleInputEvents


	end # class InputFilter
end # module MUES

