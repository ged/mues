#!/usr/bin/env ruby
# 
# MUES::EventQueue is a thread work crew/thread pool for dispatching
# MUES::Engine events (MUES::Event objects). It provides a way of managing the
# execution of many sequential tasks in a task-per-thread model without the
# expense of creating and destroying a thread for each event which requires
# execution. It contains a supervisor thread, which is responsible for
# maintaining a pool of worker threads which it starts and kills as they become
# more or less tasked. As events are enqueued (via #enqueue), they are retrieved
# by a worker thread and executed. If the execution of the event creates
# consequential events, they are dispatched back to the Engine, and the thread
# goes back into the pool.
# 
# == Synopsis
# 
#   require "mues/EventQueue"
# 
#   queue = MUES::EventQueue.new( 2, 10, 1.5, 2 )
#   queue.enqueue( *events )
# 
# == Rcsid
# 
# $Id: eventqueue.rb,v 1.20 2002/10/25 00:22:46 deveiant Exp $
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

require "thread"
#require "sync"	<-- ConditionVariable doesn't grok these

require "mues/Object"
require "mues/WorkerThread"
require "mues/Exceptions"
require "mues/Events"

module MUES

	### A scalable thread work crew class
	class EventQueue < Object ; implements MUES::Debuggable

		include MUES::TypeCheckFunctions
		
		### Class constants
		Version	= /([\d\.]+)/.match( %q{$Revision: 1.20 $} )[1]
		Rcsid	= %q$Id: eventqueue.rb,v 1.20 2002/10/25 00:22:46 deveiant Exp $

		### Class attributes
		DefaultMinWorkers	= 2
		DefaultMaxWorkers	= 20
		DefaultThreshold	= 0.2
		DefaultSafeLevel	= 2

		# Maximum number of floating-point seconds to wait for workers when
		# shutting down.
		MaxShutdownWaitTime = 5.0


		### Create and return a new MUES::EventQueue object with the specified
		### configuration. The queue will not be running -- you'll need to call
		### #start before events will be processed. The optional <tt>name</tt>
		### #argument can be used if more than one queue is used at a time to
		### #differentiate log messages and other output. If one is not
		### #provided, a generic one is created.
		def initialize( minWorkers=DefaultMinWorkers, 
					    maxWorkers=DefaultMaxWorkers, 
					    threshold=DefaultThreshold, 
					    safeLevel=DefaultSafeLevel,
					    name=nil )

			super()

			### Set config variables
			@minWorkers	= minWorkers.to_i
			@maxWorkers = maxWorkers.to_i
			@threshold	= threshold.to_f
			@safeLevel	= safeLevel.to_i
			@name		= name || "EventQueue %d" % self.id

			debugMsg( 1, "Initializing #{@name}: max = #{@maxWorkers}, min = #{@minWorkers}, safe = #{safeLevel}" )

			### Flags
			@running		= false			# Is the supervisor running?
			@shuttingDown	= false		# Is the queue shutting down?

			### Instance variables
			@workerCount	= 0;
			@queuedEvents	= []
			@queueMutex		= Mutex.new
			@queueCond		= ConditionVariable.new
			@idleWorkers	= WorkerThreadGroup.new
			@workers		= WorkerThreadGroup.new
			@supervisor		= nil
			@strayThreads	= ThreadGroup.new

			@engine			= nil
		end


		######
		public
		######

		# The number of minimum workers to maintain
		attr_accessor :minWorkers

		# The maximum number of works to allow to run at any time
		attr_accessor :maxWorkers

		# The length of time, in seconds, that the supervisor thread should
		# pause at the end of each cycle.
		attr_accessor :threshold

		# The supervisor thread object
		attr_reader :supervisor

		# The ThreadGroup containing the worker threads not currently
		# dispatching an event.
		attr_reader :idleWorkers

		# The ThreadGroup containing the worker threads which are current
		# dispatching an event.
		attr_reader :workers

		# The name of the queue
		attr_reader :name


		### Start the supervisor thread and begin processing events. The
		### <tt>engine</tt> argument is the controlling MUES::Engine object, and
		### is used for propagating consequence events.
		def start( engine )
			checkType( engine, MUES::Engine )
			debugMsg( 1, "In start()" )
			@engine = engine

			unless @supervisor
				@supervisor = Thread.new { supervisorThreadRoutine() }
				@supervisor.abort_on_exception = true
				@supervisor.desc = "Supervisor thread for #{self.name}"
			end

			### Idle a while to let the supervisor set up
			until running?
				sleep 0.5
			end

			return true
		end

		### Add the specified +events+ to the end of the queue
		def enqueue( *events )
			events.flatten!
			return false if events.empty?
			checkEachType( events, Event )
			return false if @shuttingDown

			debugMsg( 1, "Enqueuing " + events.length.to_s + " events." )

			@queueMutex.synchronize { @queuedEvents.push( *events ) }

			return true
		end

		### Alias for #enqueue
		alias :<< :enqueue


		### Add the specified +events+ to the beginning of the queue.
		def priorityEnqueue( *events )
			events.flatten!
			checkEachType( events, Event )
			return false unless @running

			debugMsg( 1, "Enqueuing " + events.length.to_s + " priority events." )

			@queueMutex.synchronize {
				@queuedEvents.unshift( *events )
				events.length.times do @queueCond.signal end
			}
		end


		### Remove and return a pending event from the queue (if any). If
		### nonBlocking is +true+, a ThreadError will be raised if there are no
		### events in the queue; otherwise the call will block until an event
		### becomes available.
		def dequeue( nonBlocking=false )
			debugMsg( 1, "In dequeue( nonBlocking = #{nonBlocking} )." )

			event = nil

			### Get an event from the queue inside a synchronized block. If the
			### queue is currently empty, raise an exception if we were told to
			### dequeue without block, otherwise wait on the queue's condition
			### variable for the queue to be populated.
			debugMsg( 4, "Mutex is locked for dequeue." ) if @queueMutex.locked?
			@queueMutex.synchronize {
				debugMsg( 4, "In the queueMutex for dequeue." )
				debugMsg( 1, "Queue has #{@queuedEvents.length} queued events." )

				if @queuedEvents.length.zero?
					debugMsg( 4, "Queue is empty." )
					if nonBlocking
						raise ThreadError, "queue empty"
					else

						### Add the current thread to the idle threadgroup, which removes it from 
						###	the workers threadgroup, and wait on the queue mutex. Once we come out
						###	of the wait, switch ourselves back into the workers group
						debugMsg( 4, "Thread #{WorkerThread.current.id} going to sleep waiting for an event." )
						@idleWorkers.add( WorkerThread.current )
						@queueCond.wait( @queueMutex ) until @queuedEvents.length > 0
						@workers.add( WorkerThread.current )
						debugMsg( 4, "Thread #{WorkerThread.current.id} woke up. Event queue has #{@queuedEvents.size} events." )
					end
				end

				debugMsg( 5, "Shifting an event off of the queue." )
				event = @queuedEvents.shift
			}

			debugMsg( 1, "Got event from queue: #{event.to_s}")
			return event
		end


		### Inform the supervisor thread that the queue needs to be shut down, and
		### give it +secondsToWait+ seconds to finish up. Returns an array of any
		### unprocessed events that were in the queue.
		def shutdown( timeout=0 )
			discardedEvents = []

			if @running
				raise ThreadError, "Ack! Supervisor disappeared" unless @supervisor

				### Synchronize around the queue mutex, setting the shutdown flag 
				debugMsg( 1, "Shutting down." )
				@queueMutex.synchronize {
					@shuttingDown = true
					# debugMsg( 1, "Clearing #{@queuedEvents.length.to_s} pending events from the queue." )
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

			return true
		end


		### Halt all queue threads forcefully.
		def halt
			debugMsg( 1, "Forcefully halting all threads." )

			return true unless @running
			deadThreads = ThreadGroup.new

			begin
				@queueMutex.synchronize {

					### Kill the supervisor thread
					if ( @supervisor.is_a? Thread ) then
						@supervisor.kill
						@supervisor.join( 0.5 )
						@supervisor = nil
					end

					### Kill all the idle threads
					@idleWorkers.list.each do |worker|
						deadThreads.add worker
						killWorkerThread( worker )
					end

					### Kill all the worker threads
					@workers.list.each do |worker|
						deadThreads.add worker
						killWorkerThread( worker )
					end
				}

			rescue StandardError => e

				### :FIXME: Some other persistent behaviour (retry?) would probably be more useful
				debugMsg( 1, "Caught exception while killing queue threads: #{e.to_s}" )
				return false
			end

			@running = false
			return true
		end

		### Returns +true+ if the queue is currently started and running
		def running?
			return @running
		end


		#########
		protected
		#########

		### The supervisor thread routine.
		def supervisorThreadRoutine

			###	Start the minimum number of worker threads
			@queueMutex.synchronize {
				debugMsg( 1, "Starting #{@minWorkers} initial worker threads." )
				@minWorkers.to_i.times do |i|
					debugMsg( 4, "Starting initial worker #{i}." )
					startWorker()
				end
				debugMsg( 2, "Initial worker threads started." )
			}

			### Toggle the running flag
			self.log.info( "#{self.name}: Started initial workers. Setting state to 'running'." )
			@running = true
			throttleLoop()
			@running = false
			self.log.info( "#{self.name}: Exiting throttle loop. Entering shutdown cycle." )

			shutWorkersDown()

			self.log.notice( "#{self.name}: Supervisor thread exiting." )
		end

		
		### Supervisor routine: Maintains the thread crew until the queue shuts
		### down and there are no more events to process.
		def throttleLoop

			# Define a thread group where threads go when they're killed off
			workerCemetary = ThreadGroup.new

			until @queuedEvents.empty? && @shuttingDown

				debugMsg( 3, "Supervisor: In throttle loop" )
				removeStrayThreads()

				### Wake the waiting worker threads if there's events to process
				@queueMutex.synchronize {
					@queueCond.broadcast if @queuedEvents.length.nonzero?
				}

				### If there're no more idle workers and there are events left in the
				### queue, start a new worker unless we're already maxed out
				if @idleWorkers.list.empty?
					@queueMutex.synchronize {
						if @idleWorkers.list.length + @workers.list.length < @maxWorkers
							startWorker()
						else
							debugMsg( 1, "Max worker limit reached with #{@queuedEvents.length} events queued." )
						end
					}

				### If there's no more events to be processed, and there are workers
				### idle, kill one unless we're at the minimum already
				elsif @queuedEvents.empty?
					@queueMutex.synchronize {
						if @idleWorkers.list.length + @workers.list.length > @minWorkers && ! @idleWorkers.list.empty?

							targetWorker = @idleWorkers.list[0]
							workerCemetary.add( targetWorker )

							debugMsg( 1, "Killing worker thread #{targetWorker.id} at idle threshold" )
							killWorkerThread( targetWorker )
						end
					}
				end

				### Assure that the queue has the minimum number of workers
				until @idleWorkers.list.length + @workers.list.length >= @minWorkers
					startWorker()
				end

				### Now sleep a while before the next loop
				debugMsg( 3, "Sleeping for #{@threshold} seconds." )
				sleep @threshold
			end

		end


		### Supervisor routine: Queues thread shutdown events for any idle
		### threads, and waits on ones that are still working until all are shut
		### down.
		def shutWorkersDown
			startTime = Time::now
			removeStrayThreads()

			### :FIXME: Is there a race condition here because a thread could
			### grab an event and move from the idleWorkers list to the workers
			### list in between the tests? Maybe not, as nothing touches the
			### condition variable outside of a synchronized block...
			until ( (@workers.list.empty? && @idleWorkers.list.empty?) ||
				Time::now - startTime > MaxShutdownWaitTime )

				if ! @idleWorkers.list.empty?
					workersRemaining = @idleWorkers.list.length
					self.log.info( "%s: Sending shutdown events to %d idle workers. %d active workers remain." % [
									  self.name, workersRemaining, @workers.list.length ] )
					@queueMutex.synchronize {
						@idleWorkers.list.each do
							@queuedEvents.push( ThreadShutdownEvent::new )
						end
						@queueCond.broadcast
					}
				else
					self.log.info( "%s: %d workers still busy after %0.2f seconds." % 
								   [self.name, @workers.list.length, Time::now - startTime] )
				end

				### :TODO: We should join the exiting threads here, probably,
				### but how to ensure we're joining an exiting thread?

				sleep 0.5
			end

			# If there are still threads around, kill 'em.
			@workers.list.each {|worker|
				self.log.warn( "Forcefully killing worker thread #{worker.desc}" )
				killWorkerThread( worker )
			}
		end


		### The worker thread routine.
		def workerThreadRoutine( threadNumber )
			debugMsg( 1, "Worker #{WorkerThread.current.id} reporting for duty." )
			$SAFE = @safeLevel

			### Get the first event
			event = dequeue()
			debugMsg( 1, "Dequeued event (#{event.class.name}) #{event.to_s}" )

			### Dispatch events until we're told to exit
			while ( ! event.is_a?( ThreadShutdownEvent ) )

				# Put consequences in their own scope so we don't hold on to their
				# references after enqueuing them
				begin
					consequences = dispatchEvent( event )
					#enqueue( *consequences ) unless consequences.empty?
					@engine.dispatchEvents( *consequences ) unless consequences.empty?
				end

				event = dequeue()

				debugMsg( 1, "Dequeued event (#{event.class.name}) #{event.to_s}" )
			end

			thr = WorkerThread.current
			debugMsg( 1, "Worker #{thr.id} going home after #{thr.runtime} seconds of faithful service." )
		end


		### Remove any threads started by worker threads from the worker thread
		### groups.
		def removeStrayThreads
			# Clean out any stray sub-threads from the our threadgroups so we're
			# only trying to kill ones we can talk to.
			(@workers.list + @idleWorkers.list).find_all {|thr|
				!thr.kind_of? WorkerThread
			}.each {|thr|
				@strayThreads.add thr
			}
		end


		### Dispatch the given +event+.
		def dispatchEvent( event )
			checkType( event, MUES::Event )

			debugMsg( 1, "Dispatching a #{event.class.name} in $SAFE = #{$SAFE}" )
			consequences = []

			### Iterate over each handler for this kind of event, calling each
			### one's handleEvent() method, adding any events that are returned
			### to the consequences.
			event.class.getHandlers.each do |handler|
				debugMsg( 2, "Invoking #{event.class.name} handler (a #{handler.class} object)." )

				results = handler.handleEvent( event )
				results = [ results ] unless results.is_a? Array

				results.flatten.compact.each {|resultEvent|
					raise EventRecursionError, event if resultEvent == event

					unless resultEvent.kind_of?( MUES::Event )
						self.log.error( "%s: Discarding non-event result '%s' from consequences of %s" % 
									   [self.name, resultEvent.inspect, event.to_s] )
						next
					end

					consequences << resultEvent
				}
			end

			### Return the result events
			debugMsg( 2, "Returning #{consequences.length} consequential events." )
			return consequences
		rescue ::Exception => e
			self.log.error( "#{self.name}: Untrapped exception #{e.class.name}: #{e.message}" )
			return [MUES::UntrappedExceptionEvent::new( e )]
		end


		### Start a new worker thread.
		def startWorker
			@workerCount += 1
			debugMsg( 1, "Creating new worker thread (count is #{@workerCount})." )
			worker = WorkerThread.new {
				workerThreadRoutine( @workerCount )
			}
			worker.abort_on_exception = true
			worker.desc = "Worker thread #{@workerCount} [#{self.name}]"
			@workers.add( worker )
		end


		### Kill the specified worker thread and join it immediately.
		def killWorkerThread( workerThread )
			raise ArgumentError, "Cannot kill the current thread" if workerThread == Thread.current
			raise ArgumentError, "Argument must be a worker thread" unless workerThread.is_a?( WorkerThread )

			# :TODO: Use join with timeout to prevent freezing on thread death?
			begin
				workerThread.kill
				workerThread.join
			rescue ThreadError => exception
				$stderr.puts "Thread exception while killing worker: #{exception.to_s}"
			end
		end


	end # class EventQueue
end # module MUES


