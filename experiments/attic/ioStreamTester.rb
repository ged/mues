#!/usr/bin/ruby -w

require 'mues/objectstore'
require 'mues/adapters/adapter'
require 'mues/ioeventstream'
require 'mues/ioeventfilters'
require 'mues/events'
require 'mues/config'

def main
	unless ARGV.length.nonzero?
		$stderr.puts "usage: #{$0} <username> [<driver>]"
		exit 1
	end

	user = ARGV.shift
	driver = ARGV.shift || "Mysql"

	config = MUES::Config.new( "bin/MUES.cfg" )
	engine = MUES::Engine.instance or raise Exception, "Failed to fetch engine instance"
	engine.start( config )

	MUES::ObjectStore::Adapter.debugLevel = 5

	puts "Fetching user record for '#{user}' from a #{driver} objectstore."
	os = MUES::ObjectStore.new( driver, 'mues', 'localhost', 'deveiant', '3l3g4nt' )
	user = os.fetchUser( user ) or raise Exception, "Could not find user '#{user}'."

	puts "User loaded. Creating IO event stream and filters."

	consoleFilter = MUES::ConsoleOutputFilter.instance
	consoleFilter.debugLevel = 0

	ios = MUES::IOEventStream.new
	ios.debugLevel = 0
	ios.addFilters( consoleFilter )

	puts "Activating user."

	user.activate( ios )
	consoleFilter.ioThread.join

	ios.shutdown
	ios.streamThread.join
end


### A fake engine class to handle subsystem calls so we don't really instantiate
### one.
module MUES
	class Engine < Object
		@@FakeEngineInstance = nil

		private_class_method :new
		attr_reader :config

		def Engine.instance
			$stderr.puts "Instantiating fake engine object." unless @@FakeEngineInstance
			@@FakeEngineInstance ||= new()
		end

		def start( config )
			$stderr.puts "Faking engine startup."
			@config = config
			MUES::Notifiable.classes.each {|klass|
				klass.atEngineStartup( self )
			}
		end

		def stop
			$stderr.puts "Faking engine shutdown."
			MUES::Notifiable.classes.each {|klass|
				klass.atEngineShutdown( self )
			}
		end

		def initialize
			@config = nil
		end

		def dispatchEvents( *events )
			$stderr.puts "Got events to dispatch:"
			events.each {|e|

				case e
				when UserLogoutEvent
					$stderr.puts "--> User logout event"
					res = e.user.deactivate
					unless res.flatten.empty?
						$stderr.puts "Got result events: \n\t" + 
							res.flatten.collect {|e| e.to_s}.join("\n\t") +
							"\n\n"
					end

				when EngineShutdownEvent
					$stderr.puts "--> No engine running. Try /quit instead."

				else
					$stderr.puts "--> #{e.to_s}"
				end
			}

		end
		
		def scheduleEvents( time, *events )
			$stderr.puts "Got events to schedule for #{time}:"
			events.each {|e|
				$stderr.puts "--> #{e.to_s}"
			}
		end

		def cancelScheduledEvents( *events )
			$stderr.puts "Got events to cancel:"
			events.each {|e|
				$stderr.puts "--> #{e.to_s}"
			}
		end
		
		def statusString
			"(Fake Engine)\n"
		end

		def method_missing( aSymbol, *args )
			methName = aSymbol.id2name
			$stderr.puts "Method #{methName} called with #{args.length} args:" +
				args.collect {|a| a.to_s}.join(', ')

			return true
		end

	end
end


main
