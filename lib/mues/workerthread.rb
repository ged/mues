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
# $Id: workerthread.rb,v 1.10 2002/09/12 12:14:59 deveiant Exp $
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
require "mues/Object"
require "mues/Mixins"


### Add a description attribute to the thread class for diagnostics
class Thread

	# The thread description
	attr_accessor :desc

	alias_method :__initialize, :initialize

	### Override the default initializer to set the description attribute for
	### all threads.
	def initialize( *args, &block )
		__initialize( *args, &block )
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

	end # class WorkerThread


	### A ThreadGroup subclass that only allows MUES::WorkerThreads to be added to it.
	class WorkerThreadGroup < ThreadGroup ; implements MUES::Debuggable
		
		include MUES::TypeCheckFunctions

		### Add a thread (a MUES::WorkerThread object) to the group. Adding any
		### other kind of thread will result in an exception being raised.
		def add( thread )
			checkType( thread, MUES::WorkerThread )
			super( thread )
		end

	end # class WorkerThreadGroup

end

