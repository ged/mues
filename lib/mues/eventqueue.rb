#!/usr/bin/env ruby
###########################################################################

=begin 

= EventQueue.rb
== Name

MUES::EventQueue - a scalable thread work crew class for the FaerieMUD server.

== Synopsis

  require "mues/EventQueue"

  queue = MUES::EventQueue.new( 2, 10, 1.5, events )
  queue.enqueue( moreEvents )

== Description

MUES::EventQueue is a thread work crew for the MUES Engine. It^s still experimental at
this point.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

###########################################################################

require "thread"
#require "sync"	<-- ConditionVariable doesn't grok these

require "mues/Namespace"
require "mues/WorkerThread"
require "mues/Exceptions"
require "mues/Events"

module MUES

	### Thread work group class
	class EventQueue < Object ; implements Debuggable

		### Class constants
		Version	= /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid	= %q$Id: eventqueue.rb,v 1.6 2001/07/18 01:48:37 deveiant Exp $

		### Class attributes
		@@DefaultMinWorkers	= 2
		@@DefaultMaxWorkers	= 20
		@@DefaultThreshold	= 0.2
		@@DefaultSafeLevel	= 2

		### (PROTECTED) METHOD: initialize( minWorkers=Fixnum, maxWorkers=Fixnum,
		###											threadThreshold=Float, safeLevel=Fixnum )
		### Initialize the queue object
		protected
		def initialize( minWorkers=@@DefaultMinWorkers, 
					    maxWorkers=@@DefaultMaxWorkers, 
					    thresh=@@DefaultThreshold, 
					    safeLevel=@@DefaultSafeLevel )

			super()
			WorkerThread.abort_on_exception = 1

			### Set config variables
			@minWorkers = minWorkers.to_i
			@maxWorkers = maxWorkers.to_i
			@threshold = thresh.to_f
			@safeLevel = safeLevel.to_i

			_debugMsg( 1, "Initializing event queue: max = #{@maxWorkers}, min = #{@minWorkers}" )

			### Flags
			@running = false			# Is the supervisor running?
			@shuttingDown = false		# Is the queue shutting down?

			### Instance variables
			@workerCount = 0;
			@queuedEvents = []
			@queueMutex = Mutex.new
			@queueCond = ConditionVariable.new
			@idleWorkers = ThreadGroup.new
			@workers = ThreadGroup.new
			@supervisor = nil
			@supervisorMutex = Mutex.new
		end

		###############################################################################
		###	P U B L I C   M E T H O D S
		###############################################################################
		public

		### Attribute accessors
		attr_accessor :minWorkers, :maxWorkers, :threshold
		attr_reader	:threadCount, :idle, :supervisor, :idleWorkers, :workers

		### METHOD: start()
		### Start the supervisor thread and begin processing events
		def start
			_debugMsg( 1, "In start()" )
			@supervisorMutex.synchronize {
				unless @supervisor
					@supervisor = Thread.new { _supervisorThreadRoutine() }
					@supervisor.abort_on_exception = true
					@supervisor.desc = "Supervisor thread for EventQueue #{self.id}"
				end
			}

			### Idle a while to let the supervisor set up
			until running?
				sleep 0.5
			end

			return true
		end

		### METHOD: enqueue( *events )
		### Add the specified events to the end of the queue of pending events
		def enqueue( *events )
			events.flatten!
			checkEachType( events, Event )
			return false if @shuttingDown

			_debugMsg( 1, "Enqueuing " + events.length.to_s + " events." )

			@queueMutex.synchronize {
				@queuedEvents.push( *events )
			}

			return true
		end

		### METHOD: <<( *events )
		### Alias for enqueue( events )
		alias :<< :enqueue

		### METHOD: priorityEnqueue( events=[ Event ] )
		### Add the specified events to the beginning of the queue of pending events
		def priorityEnqueue( *events )
			events.flatten!
			checkEachType( events, Event )
			return false unless @running

			_debugMsg( 1, "Enqueuing " + events.length.to_s + " priority events." )

			@queueMutex.synchronize {
				@queuedEvents.unshift( *events )
				events.length.times do @queueCond.signal end
			}
		end


		### METHOD: dequeue()
		### Remove and return a pending event from the queue (if any)
		def dequeue( nonBlocking=false )
			_debugMsg( 1, "In dequeue( nonBlocking = #{nonBlocking} )." )

			event = nil

			### Get an event from the queue inside a synchronized block. If the
			### queue is currently empty, raise an exception if we were told to
			### dequeue without block, otherwise wait on the queue's condition
			### variable for the queue to be populated.
			_debugMsg( 4, "Mutex is locked for dequeue." ) if @queueMutex.locked?
			@queueMutex.synchronize {
				_debugMsg( 4, "In the queueMutex for dequeue." )
				_debugMsg( 1, "Queue has #{@queuedEvents.length} queued events." )

				if @queuedEvents.length.zero?
					_debugMsg( 4, "Queue is empty." )
					if nonBlocking
						raise ThreadError, "queue empty"
					else

						### Add the current thread to the idle threadgroup, which removes it from 
						###	the workers threadgroup, and wait on the queue mutex. Once we come out
						###	of the wait, switch ourselves back into the workers group
						_debugMsg( 4, "Thread #{WorkerThread.current.id} going to sleep waiting for an event." )
						@idleWorkers.add( WorkerThread.current )
						@queueCond.wait( @queueMutex ) until @queuedEvents.length > 0
						@workers.add( WorkerThread.current )
						_debugMsg( 4, "Thread #{WorkerThread.current.id} woke up. Event queue has #{@queuedEvents.size} events." )
					end
				end

				_debugMsg( 5, "Shifting an event off of the queue." )
				event = @queuedEvents.shift
			}

			_debugMsg( 1, "Got event from queue: #{event.to_s}")
			return event
		end


		### METHOD: shutdown( secondsToWait )
		### Inform the supervisor thread that the queue needs to be shut down, and
		### give it secondsToWait seconds to finish up. Returns any array of any
		### unprocessed events that were in the queue.
		def shutdown( timeout=0 )
			discardedEvents = []

			@supervisorMutex.synchronize {
				if @running
					raise ThreadError, "Ack! Supervisor disappeared" unless @supervisor

					### Synchronize around the queue mutex, setting the shutdown flag 
					_debugMsg( 1, "Shutting down." )
					@queueMutex.synchronize {
						@shuttingDown = true
						# _debugMsg( 1, "Clearing #{@queuedEvents.length.to_s} pending events from the queue." )
						# discardedEvents << @queuedEvents
						# @queuedEvents.clear
					}

					### If we got a timeout, allow that length of time before
					### halting all threads forcefully
					if timeout.nonzero?
						until( ! @running || timeout < 1 )
							sleep 1
							timeout -= 1
						end

						if ( ! @running ) then
							@supervisor.join
						else
							halt()
						end

					### If we didn't get a timeout, just wait until the
					### queue has shut down on its own
					else
						until( ! @running )
							sleep 1
						end

						@supervisor.join
					end
				end
			}

			return true
		end


		### METHOD: halt()
		### Halt all queue threads forcefully.
		def halt
			_debugMsg( 1, "Forcefully halting all threads." )

			return true unless @running
			deadThreads = ThreadGroup.new

			begin
				@queueMutex.synchronize {

					### Kill the supervisor thread
					if ( @supervisor.is_a? Thread ) then
						@supervisor.kill
						@supervisor.join
						@supervisor = nil
					end

					### Kill all the idle threads
					@idleWorkers.list.each do |worker|
						deadThreads.add worker
						_killWorkerThread( worker )
					end

					### Kill all the worker threads
					@workers.list.each do |worker|
						deadThreads.add worker
						_killWorkerThread( worker )
					end
				}

			rescue StandardError => e

				### :FIXME: Some other persistent behaviour (retry?) would probably be more useful
				_debugMsg( 1, "Caught exception while killing queue threads: #{e.to_s}" )
				return false
			end

			@running = false
			return true
		end

		### METHOD: running?
		### Returns true if the queue is currently started and running
		def running?
			return @running
		end


		###############################################################################
		###	P R O T E C T E D   M E T H O D S
		###############################################################################
		protected

		### (PROTECTED) METHOD: _supervisorThreadRoutine()
		### The supervisor thread work method.
		def _supervisorThreadRoutine

			# Define a thread group where threads go when they're killed off
			workerCemetary = ThreadGroup.new

			###	Start the minimum number of worker threads
			@queueMutex.synchronize {
				_debugMsg( 1, "Starting #{@minWorkers} initial worker threads." )
				@minWorkers.to_i.times do |i|
					_debugMsg( 4, "Starting initial worker #{i}." )
					_startWorker()
				end
				_debugMsg( 2, "Done starting worker threads." )
			}

			### Toggle the running flag
			_debugMsg( 1, "Started initial workers. Setting state to 'running'." )
			@running = true

			### Maintain the thread crew until the queue shuts down and there
			### are no more events to process.
			until @queuedEvents.empty? && @shuttingDown

				_debugMsg( 3, "Supervisor: In throttle loop" )

				### Wake the waiting worker threads if there's events to process
				@queueMutex.synchronize {
					@queueCond.broadcast if @queuedEvents.length.nonzero?
				}

				### If there're no more idle workers and there are events left in the
				### queue, start a new worker unless we're already maxed out
				if @idleWorkers.list.empty?
					@queueMutex.synchronize {
						if @idleWorkers.list.length + @workers.list.length < @maxWorkers
							_startWorker()
						else
							_debugMsg( 1, "Max worker limit reached with #{@queuedEvents.length} events queued." )
						end
					}

				### If there's no more events to be processed, and there are workers
				### idle, kill one unless we're at the minimum already
				elsif @queuedEvents.empty?
					@queueMutex.synchronize {
						if @idleWorkers.list.length + @workers.list.length > @minWorkers && ! @idleWorkers.list.empty?

							targetWorker = @idleWorkers.list[0]
							workerCemetary.add( targetWorker )

							_debugMsg( 1, "Killing worker thread #{targetWorker.id} at idle threshold" )
							_killWorkerThread( targetWorker )
						end
					}
				end

				### Assure that the queue has the minimum number of workers
				until @idleWorkers.list.length + @workers.list.length >= @minWorkers
					_startWorker()
				end

				### Now sleep a while before the next loop
				_debugMsg( 3, "Sleeping for #{@threshold} seconds." )
				sleep @threshold
			end

			@running = false
			_debugMsg( 1, "Supervisor: Exiting throttle loop. Entering shutdown cycle." )

			### Queue thread shutdown events for any idle threads, and wait on ones that are still
			###		working.
			### :FIXME: Is there a race condition here because a thread could
			### grab an event and move from the idleWorkers list to the workers
			### list in between the tests? Maybe not, as nothing touches the
			### condition variable outside of a synchronized block...
			until @workers.list.empty? && @idleWorkers.list.empty?

				if ! @idleWorkers.list.empty?
					workersRemaining = @idleWorkers.list.length
					_debugMsg( 1, "Supervisor: Sending shutdown events to #{workersRemaining} idle workers. #{@workers.list.length} active workers remain." )
					@queueMutex.synchronize {
						@idleWorkers.list.each do
							@queuedEvents.push( ThreadShutdownEvent.new )
						end
						@queueCond.broadcast
					}
				end

				### :TODO: We should join the exiting threads here, probably,
				### but how to ensure we're joining an exiting thread?

				sleep 0.25
			end

			_debugMsg( 1, "Supervisor: Exiting" )

		end


		### (PROTECTED) METHOD: _workerThreadRoutine()
		### The worker thread work method.
		def _workerThreadRoutine( threadNumber )
			_debugMsg( 1, "Worker #{WorkerThread.current.id} reporting for duty." )
			$SAFE = @safeLevel
			thr = WorkerThread.current

			### Get the first event
			event = dequeue()
			_debugMsg( 1, "Dequeued event (#{event.class.name}) #{event.to_s}" )

			### Dispatch events until we're told to exit
			while ( ! event.is_a?( ThreadShutdownEvent ) )
				consequences = _dispatchEvent( event )
				enqueue( *consequences ) if consequences.size > 0
				event = dequeue()
				_debugMsg( 1, "Dequeued event (#{event.class.name}) #{event.to_s}" )
			end

			_debugMsg( 1, "Worker #{thr.id} going home after #{thr.runtime} seconds of faithful service." )
		end


		### (PROTECTED) METHOD: _dispatchEvent( event )
		### Dispatch the given event to the handlers which have registered themselves
		###		with the event's class.
		def _dispatchEvent( event )
			unless event.is_a?( Event ) then
				raise ArgumentError, "Argument '#{event.class.name}' is not an event object."
			end

			_debugMsg( 1, "Dispatching a #{event.class.name}" )
			consequences = []

			### Iterate over each handler for this kind of event, calling each ones
			### handleEvent() method, adding any events that are returned to the consequences.
			event.class.GetHandlers.each do |handler|
				_debugMsg( 1, "Invoking #{event.class.name} handler (a #{handler.class} object)." )
				begin
					result = handler.handleEvent( event )
					if result.is_a?( Array ) then
						_debugMsg( 2, "Got an array of #{result.length} result objects in response." )
						recurseEvent = result.detect {|e| e == event}
						if recurseEvent
							_debugMsg( 1, "Recursion error. Result for event #{e} contained a copy of itself." )
							raise EventRecursionError( recurseEvent )
						end
						consequences += result
					elsif result.is_a?( Event ) then
						_debugMsg( 2, "Got a single event object as a result." )
						if result == event
							_debugMsg( 1, "Recursion error. Result for event #{e} was a copy of itself." )
							raise EventRecursionError( result )
						end
						consequences << result
					end
				rescue StandardError => e
					_debugMsg( 1, "Encountered untrapped exception #{e.type.name}: #{e.message}" )
					consequences << UntrappedExceptionEvent.new( e )
				end
			end

			### Return a flattened version of the result events
			_debugMsg( 2, "Returning #{consequences.length} consequential events." )
			return consequences.flatten
		end


		### (PROTECTED) METHOD: _startWorker()
		### Start a new worker thread
		def _startWorker
			@workerCount += 1
			_debugMsg( 1, "Creating new worker thread (count is #{@workerCount})." )
			worker = WorkerThread.new {
				_workerThreadRoutine( @workerCount )
			}
			worker.abort_on_exception = true
			worker.desc = "Worker thread #{@workerCount} [Queue #{self.id}]"
			@workers.add( worker )
		end


		### (PROITECTED) METHOD: _killWorkerThread( workerThread )
		### Kill the specified worker thread and join it right away
		def _killWorkerThread( workerThread )
			raise ArgumentError, "Cannot kill the current thread" if workerThread == Thread.current
			raise ArgumentError, "Argument must be a worker thread" unless workerThread.is_a?( WorkerThread )

			begin
				workerThread.kill
				workerThread.join
			rescue ThreadError => exception
				$stderr.puts "Thread exception while killing worker: #{exception.to_s}"
			end
		end


	end # class EventQueue
end # module MUES


