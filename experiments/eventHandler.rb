#!/usr/bin/ruby


require "mues/Events"
include MUES

class Handler < Object

	include MUES::Event::Handler

  protected
	def handleSystemEvent( event )
		puts "Handled system event: #{event.to_s}"
	end

	def handleTestSystemEvent( event )
		puts "Handled test system event: #{event.to_s}"
	end

	def handleTickEvent( event )
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


class TestSystemEvent < MUES::SystemEvent; end
class TestWorldEvent < MUES::EnvironmentEvent; end

h = Handler.new
eventsToGenerate = [ Shutdown, EngineShutdownEvent, TestSystemEvent, TestWorldEvent ]


eventsToGenerate.each do |klass|
	klass.RegisterHandlers( h )
end

eventsToGenerate.each do |klass|
	ev = klass.new
	dispatchEvent( ev )
end

