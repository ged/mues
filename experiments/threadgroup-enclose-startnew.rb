#!/usr/bin/env ruby

# Test to see if new threads started by a thread belonging to an
# enclosed ThreadGroup are members of their parent ThreadGroup (even
# though it's been enclosed)

tg = ThreadGroup.new

t = Thread.new do
	Thread.current.abort_on_exception = true

	until Thread.current.group && Thread.current.group.enclosed?
		puts "Waiting to be put into a ThreadGroup..."
		sleep 1
	end

	subthreads = []

	5.times do
		subthread = Thread.new { sleep 5 }
		subthreads << subthread
	end

	subthreads.each do |sthr|
		sthr.join
	end
end

tg.add( t )
tg.enclose

while t.alive?
	puts "ThreadGroup has threads: ",
		tg.list.collect {|thr| "  %p" % [thr] }
	sleep 1
end

