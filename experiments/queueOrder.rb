#!/usr/bin/ruby

require "mues/EventQueue"
require "mues/Events"

class DebugOutputEventHandler < Object
	def handleEvent( e )
		sleepTime = rand 5
		$stderr.puts( "(Handler): Got event #{e.id} (##{e.count}) " +
					  "in thread #{360_000_000 - Thread.current.id}. " +
					  "Sleeping #{sleepTime} seconds." )
		sleep sleepTime
	end
end

DebugOutputEvent.RegisterHandlers( DebugOutputEventHandler.new )

queue = EventQueue.new
#queue.debug( 1 )
queue.start

45.times do |count|
	ev = DebugOutputEvent.new( count + 1 )
	# $stderr.puts "Queueing a DebugOutputEvent: #{ev.to_s}"
	queue.enqueue( ev )
end

15.times do |countdown|
	$stderr.puts ">>> Main thread sleeping... #{15 - countdown}."
	sleep 1
end

queue.shutdown
#queue.halt
