#!/usr/bin/ruby -w

require "thread"

$gate = ConditionVariable.new
$gateLock = Mutex.new
$basket = []

class Shutdown < Exception; end

def supplier
	$stderr.puts "Supplier starting up."

	begin
		loop do
			$stderr.puts "Supplier: sleeping for a bit."
			sleep rand(5)
			$stderr.puts "Supplier: waking up."
			$gateLock.synchronize {
				thingie = Time.new
				$stderr.puts "Supplier: In the gate, putting #{thingie.to_s} in the basket."
				$basket << thingie
				$stderr.puts "Supplier: Signalling."
				$gate.signal
			}
			$stderr.puts "Supplier: Out of the gate, done putting."
		end
	rescue Shutdown
		$stderr.puts "Supplier: shutting down."
	end

	$stderr.puts "Supplier: going home."
end

def consumer
	$stderr.puts "Consumer: starting up."

	begin
		loop do
			$stderr.puts "Consumer: Trying to get something from the basket"
			$gateLock.synchronize {
				begin 
					$stderr.puts "Consumer: In the gate, waiting on the gateLock"
					$gate.wait( $gateLock )
					$stderr.puts "Consumer: Back from waiting. Basket has #{$basket.length} items."
				end while $basket.empty?
				
				thingie = $basket.shift
				$stderr.puts "Consumer: Got '#{thingie.to_s}' from the basket."
			}
			$stderr.puts "Consumer: Out of the gate, done fetching."
		end
	rescue Shutdown
		$stderr.puts "Consumer: shutting down."
	end

	$stderr.puts "Consumer: going home."
end

sThread = cThread = nil

Thread.abort_on_exception = true

$stderr.puts "Creating supplier thread."
sThread = Thread.new { supplier }
sThread.abort_on_exception = true
$stderr.puts "Supplier thread == #{sThread.id}."

$stderr.puts "Creating consumer thread."
cThread = Thread.new { consumer }
cThread.abort_on_exception = true
$stderr.puts "Consumer thread == #{cThread.id}."

sThread.join
cThread.join

