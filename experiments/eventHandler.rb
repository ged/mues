#!/usr/bin/ruby


require "mues/Events"

class Handler < Object

	include MUES::Event::Handler

  protected
	def _handleSystemEvent( event )
		puts "Handled system event: #{event.to_s}"
	end

	def _handleTestSystemEvent( event )
		puts "Handled test system event: #{event.to_s}"
	end

	def _handleTickEvent( event )
		puts "Handled tick event: #{event.to_s}"
	end

end

def dispatchEvent( event )
	raise ArgumentError, "Argument must be an event object" unless event.is_a?( Event )

	### Iterate over each handler for this kind of event, calling each ones
	### handleEvent() method, adding any events that are returned to the consequences.
	event.class.GetHandlers.each do |handler|
		begin
			result = handler.handleEvent( event )
		rescue Exception => e
			$stderr.puts "Ack! #{e.class.name}: #{e.to_s}"
			$stderr.puts "\t" + e.backtrace.join("\n\t")
			next
		end
	end

	return true
end


class TestSystemEvent < SystemEvent; end
class TestWorldEvent < WorldEvent; end

h = Handler.new
eventsToGenerate = [ ThreadShutdownEvent, EngineShutdownEvent, TestSystemEvent, TestWorldEvent ]


eventsToGenerate.each do |klass|
	klass.RegisterHandlers( h )
end

eventsToGenerate.each do |klass|
	ev = klass.new
	dispatchEvent( ev )
end

