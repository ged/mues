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

		### Accessors
		attr_accessor :stopTime
		
		### (PROTECTED) METHOD: initialize( *args )
		### Initialize the thread with the given arguments.
		protected
		def initialize( *args )
			$SAFE = 2
			@stopTime = Time.now
			_debugMsg( 1, "Initializing worker thread at #{@stopTime.ctime}" )
			super { yield(args[0]) }
		end

		### METHOD: timestamp()
		### Stamp the thread with the current time
		public
		def timestamp
			stopTime( Time.now )
		end

	end
end

