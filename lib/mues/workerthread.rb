#!/usr/bin/env ruby
###########################################################################

=begin
=end

###########################################################################

require "thread"
require "mues/Debugging"
require "mues/MUES"

module MUES
	class WorkerThread < Thread

		include Debuggable

		attr_accessor :stopTime
		
		### METHOD: initialize
		def initialize( *args )
			$SAFE = 2
			@stopTime = Time.now
			_debugMsg( "Initializing worker thread at #{@stopTime.ctime}" )
			super { yield(args[0]) }
		end

		def timestamp
			stopTime( Time.now )
		end

	end
end

