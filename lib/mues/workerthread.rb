#!/usr/bin/env ruby
# 
# This file provides a derivative of the Thread class which is capable of storing an
# associated timestamp. This functionality can be used to ascertain how long the
# thread has been in an idle state.
# 
# == Synopsis
# 
#   require "mues/WorkerThread"
#
#	thr = WorkerThread.new( args ) {|args| doSomething() }
#
#	puts "Thread #{thr.desc} has been running for #{thr.runtime} seconds."
# 
# == Rcsid
# 
# $Id: workerthread.rb,v 1.8 2002/08/01 01:14:08 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#---
# Please see the file COPYRIGHT for licensing details.
#


require "thread"
require "mues"

### Add a description attribute to the thread class for diagnostics
class Thread

	# The thread description
	attr_accessor :desc

	alias_method :realInitialize, :initialize

	### Override the default initializer to set the description attribute for
	### all threads.
	def initialize( *args, &block )
		realInitialize( *args, &block )
		self.desc = "(unknown): started from #{caller(1)[0]}"
	end
end

module MUES

	### A thread subclass for worker threads in EventQueues
	class WorkerThread < Thread ; implements MUES::Debuggable

		### Create and return the thread with the given arguments.
		def initialize( *args ) # :yeilds: *args
			@startTime = Time.now
			debugMsg( 1, "Initializing worker thread at #{@startTime.ctime}" )
			super { yield(*args) }
		end


		######
		public
		######

		# The thread's start time
		attr_reader :startTime
		
		### Returns the number of seconds this thread has been running
		def runtime
			return Time.now.to_i - @startTime.to_i
		end

	end
end

