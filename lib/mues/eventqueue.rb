#!/usr/bin/env ruby
###########################################################################

=begin

= EventQueue.rb

== NAME

MUES::EventQueue - a scalable thread work crew class for the FaerieMUD server.

== SYNOPSIS

  require "mues/eventqueue"

  queue = MUES::EventQueue.new( 2, 10, 1.5, events )
  queue.enqueue( moreEvents )

== DESCRIPTION

MUES::EventQueue is a thread work crew for the MUES Engine. It^s still experimental at
this point.

== AUTHOR

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

###########################################################################
require "mues/WorkerThread"
require "mues/Exceptions"
require "mues/Events"
require "mues/Debugging"

module MUES

	### Thread work group class
	class EventQueue < Object

		include Debuggable

		attr_accessor :minWorkers, :maxWorkers, :threshold
		attr_reader	:threadCount, :idle, :supervisor, :idleWorkers, :workers

		@@DefaultMinWorkers = 2
		@@DefaultMaxWorkers = 20
		@@DefaultThreshold = 0.2
		@@DefaultSafeLevel = 2

		###############################################################################
		###	P U B L I C   M E T H O D S
		###############################################################################
		public

		### METHOD: initialize( minWorkers=Fixnum, maxWorkers=Fixnum,
		###							threadThreshold=Float, safeLevel=Fixnum )
		### Initialize the queue and start up its workers
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
			@running = false
			@shuttingDown = false

			_debugMsg( "Initializing event queue: max = #{@maxWorkers}, min = #{@minWorkers}" )

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


		### METHOD: start()
		### Start the supervisor thread and begin processing events
		def start
			_debugMsg( "In start()" )
			@supervisorMutex.synchronize {
				unless @supervisor
					@supervisor = Thread.new { _supervisorThreadRoutine() }
					@supervisor.abort_on_exception = 1
				end
			}
			return true
		end

		### METHOD: enqueue( events=[ Event ] )
		### Add the specified events to the end of the queue of pending events
		def enqueue( *events )
			_debugMsg( "Enqueuing " + events.length.to_s + " events." )
			@queueMutex.synchronize {
				@queuedEvents += events
				@queuedEvents.flatten!
		}
		end


		### METHOD: priorityEnqueue( events=[ Event ] )
		### Add the specified events to the beginning of the queue of pending events
		def priorityEnqueue( *events )
			_debugMsg( "Enqueuing " + events.length.to_s + " priority events." )
			@queueMutex.synchronize {
				@queuedEvents.unshift( events )
				@queueCond.signal
			}
		end


		### METHOD: dequeue()
		### Remove and return a pending event from the queue (if any)
		def dequeue( nonBlocking=false )
			_debugMsg( "Entering queue for event." )

			event = nil

			### Get an event from the queue inside a synchronized block. If the
			### queue is currently empty, raise an exception if we were told to
			### dequeue without block, otherwise wait on the queue's condition
			### variable for the queue to be populated.
			@queueMutex.synchronize {
				_debugMsg( "Queue has #{@queuedEvents.length} queued events." )

				if @queuedEvents.length == 0
					if nonBlocking
						raise ThreadError, "queue empty"
					else

						### Add the current thread to the idle threadgroup, which removes it from 
						###	the workers threadgroup, and wait on the queue mutex. Once we come out
						###	of the wait, switch ourselves back into the workers group
						_debugMsg( "Thread #{WorkerThread.current.id} going to sleep waiting for an event." )
						@idleWorkers.add( WorkerThread.current )
						@queueCond.wait( @queueMutex ) until @queuedEvents.length > 0
						@workers.add( WorkerThread.current )
						_debugMsg( "Thread #{WorkerThread.current.id} woke up. Event queue has #{@queuedEvents.size} events." )
					end
				end

				event = @queuedEvents.shift
			}

			_debugMsg( "Got event from queue: #{event.to_s}")
			return event
		end


		### METHOD: shutdown( secondsToWait )
		### Inform the supervisor thread that the queue needs to be shut down, and
		### give it secondsToWait seconds to finish up. Returns any array of any
		### unprocessed events that were in the queue.
		def shutdown( timeout=15 )
			currentEvents = []
			@supervisorMutex.synchronize {
				return unless @supervisor

				### If the queue hasn't yet been started, just return without doing anything
				return currentEvents unless @running

				### Synchronize around the queue mutex, setting the shutdown flag 
				_debugMsg( "Shutting down." )
				@queueMutex.synchronize {
					@shuttingDown = true
					_debugMsg( "Clearing #{@queuedEvents.length.to_s} pending events from the queue." )
					currentEvents << @queuedEvents
					@queuedEvents.clear
				}

				### If we got a timeout, allow that length of time before
				### halting all threads forcefully
				if ( timeout > 0 ) then
					until( ! @running || timeout < 1 )
						sleep 1
						timeout -= 1
					end

					if ( ! @running ) then
						@supervisor.join
					else
						halt()
					end

					### If we didn't get a timeout, just wait until the queue has shut down on its own
				else
					until( ! @running )
						sleep 1
					end

					@supervisor.join
				end
			}

			return currentEvents
		end


		### METHOD: halt()
		### Halt all queue threads forcefully.
		def halt
			_debugMsg( "Forcefully halting all threads." )

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
				_debugMsg( "Caught exception while killing queue threads: #{e.to_s}" )
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
				_debugMsg( "Starting #{@minWorkers} initial worker threads." )
				@minWorkers.to_i.times do |i|
					_debugMsg( "Starting initial worker #{i}." )
					_startWorker()
				end
			}

			### Toggle the running flag
			@running = true

			### Maintain the thread crew until we're told to shut down
			until ( @shuttingDown ) do

				#_debugMsg( "Supervisor: In throttle loop" )
				@queueMutex.synchronize {
					@queuedEvents.length.times {
						@queueCond.signal
					}
				}

				### If there's no more idle workers and there are events left in the
				### queue, start a new worker unless we're already maxed out
				if ( @idleWorkers.list.length < 1 ) then
					@queueMutex.synchronize {
						if ( @idleWorkers.list.length + @workers.list.length < @maxWorkers ) then
							_startWorker()
						else
							_debugMsg( "Max worker limit reached with #{@queuedEvents.length} events queued." )
						end
					}

					### If there's no more events to be processed, and there are workers
					### idle, kill one unless we're at the minimum already
				elsif ( @queuedEvents.length < 1 ) then
					@queueMutex.synchronize {
						if ( @idleWorkers.list.length + @workers.list.length > @minWorkers && @idleWorkers.list.length > 0 ) then
							targetWorker = @idleWorkers.list.shift

							_debugMsg( "Killing worker thread #{targetWorker.id} at idle threshold" )

							workerCemetary.add( targetWorker )
							_killWorkerThread( targetWorker )
						end
					}
				end

				### Check to make sure the queue has the minimum number of workers,
				### starting one if it doesn't, and then sleep until the next loop
				_startWorker() unless @idleWorkers.list.length + @workers.list.length >= @minWorkers
				sleep @threshold

			end

			_debugMsg( "Supervisor: Exiting throttle loop. Entering shutdown cycle." )

			### Queue thread shutdown events for any idle threads, and wait on ones that are still
			###		working.
			while ( @idleWorkers.list.length > 0 || @workers.list.length > 0 )
				workersRemaining = @idleWorkers.list.length
				_debugMsg( "Sending shutdown events to #{workersRemaining} idle workers" )
				@queueMutex.synchronize {
					workersRemaining.times do
						@queuedEvents.push( ThreadShutdownEvent.new )
					end
					@queueCond.broadcast
				}

				### :TODO: We should join the exiting threads here, probably,
				### but how to ensure we're joining an exiting thread?

				sleep 0.25
			end

			_debugMsg( "Supervisor: Exiting" )
			@running = false

		end


		### (PROTECTED) METHOD: _doWork()
		### The worker thread work method.
		def _doWork( threadNumber )
			_debugMsg( "Worker #{WorkerThread.current.id} reporting for duty." )
			$SAFE = @safeLevel

			### Get the first event
			event = dequeue()
			_debugMsg( "Dequeued event (#{event.class.name}) #{event.to_s}" )

			### Dispatch events as we get them, quitting if we're given nil
			while ( ! event.is_a?( ThreadShutdownEvent ) )
				consequences = _dispatchEvent( event )
				enqueue( consequences ) if consequences.size > 0
				event = dequeue()
			end
			_debugMsg( "Worker #{WorkerThread.current.id} going home." )
		end


		### (PROTECTED) METHOD: _dispatchEvent( event )
		### Dispatch the given event to the handlers which have registered themselves
		###		with the event's class.
		def _dispatchEvent( event )
			unless event.is_a?( Event ) then
				raise ArgumentError, "Argument '#{event.class.name}' is not an event object."
			end

			_debugMsg( "Dispatching a #{event.class.name}" )
			consequences = []

			### Iterate over each handler for this kind of event, calling each ones
			### handleEvent() method, adding any events that are returned to the consequences.
			event.class.GetHandlers.each do |handler|
				_debugMsg( "Got a #{handler.class} object for a #{event.class.name}." )
				begin
					result = handler.handleEvent( event )
					if result.is_a?( Array ) then
						recurseEvent = result.detect {|e| e == event}
						raise EventRecursionError( recurseEvent ) if recurseEvent
						consequences += result
					elsif result.is_a?( Event ) then
						raise EventRecursionError( result ) if result == event
						consequences << result
					end
				rescue StandardError => e
					consequences << UntrappedExceptionEvent.new( e )
				end
			end

			### Return a flattened version of the result events
			return consequences.flatten
		end


		### (PROTECTED) METHOD: _startWorker()
		### Start a new worker thread
		def _startWorker
			_debugMsg( "Creating new worker thread (count is #{@workerCount})." )
			@workerCount += 1
			worker = WorkerThread.new { _doWork(@workerCount) }
			@workers.add( worker )
		end


		### METHOD: _killWorkerThread( workerThread )
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

end


