#!/usr/bin/ruby
# 
# This file contains the MUES::DefaultOutputFilter class, which is a
# MUES::IOEventFilter derivative for catching unhandled output events in a
# MUES::IOEventStream.
# 
# == Synopsis
# 
#   require "mues/filters/DefaultOutputFilter"
# 
# == Rcsid
# 
# $Id: defaultoutputfilter.rb,v 1.5 2002/08/02 20:03:43 deveiant Exp $
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

	# This is the default output event filter, derived from the
	# MUES::IOEventFilter class. It is included in every MUES::IOEventStream as
	# a last-resort output event handler.
	class DefaultOutputFilter < IOEventFilter

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
		Rcsid = %q$Id: defaultoutputfilter.rb,v 1.5 2002/08/02 20:03:43 deveiant Exp $
		DefaultSortPosition = 0

		### Create and return a new default output filter with a history of the
		### specified <tt>size</tt>. The filter's history is an array of the
		### most recent output events to have been caught by this filter, for
		### use in reconnections, etc.
		def initialize( size=10 )
			super()
			@history = []
			@maxHistorySize = size
		end


		######
		public
		######

		# The Array of 
		attr_accessor :history


		### Handle the specified output <tt>events</tt>. Adds the events to the
		### filter's history, trimming any older events which exceed the maximum
		### history size.
		def handleOutputEvents( *events )

			### Add event data to history
			@history += events.flatten.collect{|event| event.data}
			@history = @history[-@historySize..-1] if @history.length > @maxHistorySize
			[]
		end

	end

end
