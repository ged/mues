#!/usr/bin/ruby

require "Service"
require "TestServices"
require "drb"

class ServiceProxy < Object

	attr_accessor :uri
	@servicesOffered = nil

	def initialize( port=6565 )
		super()

		@servicesOffered = {}
		@anonClasses = {}
		self.uri = "druby://localhost:#{port}"
		puts "Starting service proxy at '#{uri}'"
		DRb.start_service( self.uri, self )
	end

	def request( serviceName, methodName, *args )
		return nil unless @servicesOffered.has_key?( serviceName )
		puts "Answering '#{serviceName}' request for '#{methodName}' with #{args.size} args."
		#return nil unless @servicesOffered[ serviceName ].respond_to?( methodName )
		@servicesOffered[ serviceName ].send( methodName, *args )
	end

	def addService( serviceName, service, *args )
		if service.is_a?(String) then
			@anonClasses[serviceName] = Class.new( Service )
			@anonClasses[serviceName].class_eval service

			service = @anonClasses[serviceName].new( *args )
		end
		puts "Adding service '#{serviceName}'."
		removeService( serviceName )
		@servicesOffered[ serviceName ] = service
		return true
	end

	def removeService( serviceName )
		return nil unless @servicesOffered.has_key?( serviceName )
		puts "Removing service '#{serviceName}'."
		@servicesOffered[serviceName].shutdown
		@servicesOffered.delete( serviceName )
	end

	def shutdown
		puts "Shutting down the proxy."
		@servicesOffered.each_key {|serviceName|
			removeService( serviceName )
		}
	end
end


if $0 == __FILE__ then
	Thread.abort_on_exception = 1

	metaService = ServiceProxy.new( 6565 )

	trap( "SIGTERM" ) { metaService.shutdown }
	trap( "SIGINT" ) { metaService.shutdown }
	trap( "SIGHUP" ) { metaService.shutdown }

	DRb.thread.join
end



