#!/usr/bin/env ruby
###########################################################################
=begin 

=WorkerThread.rb

== Name

WorkerThread - A $SAFE-ified worker object class

== Synopsis

  require "mues/WorkerThread"
  oStore = ObjectStore.new( "MySQL", "faeriemud", "localhost", "fmuser", "fmpass" )

  objectIds = oStore.storeObjects( obj ) {|obj|
	$stderr.puts "Stored object #{obj}"
  }

== Description

This class is a derivative of the Thread class which is capable of storing an
associated timestamp. This functionality can be used to ascertain how long the
thread has been in an idle state.

== Methods
=== MUES::WorkerThread
==== Protected Instance Methods

--- MUES::WorkerThread#initialize( *args )

	Set up and initialize the thread. Sets the thread^s (({$SAFE})) level to 2,
	sets the timestamp, and then calls ((<Thread#initialize>)).

==== Instance Methods

--- MUES::WorkerThread#stopTime( ((|newTime|)) )

	Sets and/or returns the thread^s current stop time (a (({Time})) object).

--- MUES::WorkerThread#timestamp()

	Set the stop time to the current time.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "thread"
require "mues/Namespace"
require "mues/Debugging"

module MUES
	class WorkerThread < Thread

		include Debuggable

		### METHOD: new( *args )
		### Initialize the thread with the given arguments.
		protected
		def initialize( *args )
			$SAFE = 2
			@startTime = Time.now
			_debugMsg( 1, "Initializing worker thread at #{@startTime.ctime}" )
			super { yield(args[0]) }
		end

		#######################################################################
		###	P U B L I C   M E T H O D S
		#######################################################################
		public

		### Accessors
		attr_accessor :startTime
		
		### METHOD: runtime
		### Returns the number of seconds this thread has been running
		def runtime
			return Time.now.to_i - startTime.to_i
		end

	end
end

