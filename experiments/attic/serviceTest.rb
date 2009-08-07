#!/usr/bin/ruby

require "drb"

class Service < Object
	attr_accessor :uri
end

class ServiceOne < Service
	def serviceName
		return "Service 1 <#{self.uri}>"
	end
end

class ServiceTwo < Service
	def serviceName
		return "Service 2 <#{self.uri}>"
	end
end

class ServiceThree < Service
	def serviceName
		return "Service 3 <#{self.uri}>"
	end
end

class ServiceFour < Service
	def serviceName
		return "Service 4 <#{self.uri}>"
	end
end

Thread.abort_on_exception = 1

services = []
port = 6565

[ ServiceOne, ServiceTwo, ServiceThree, ServiceFour ].each {|serverClass|
	service = serverClass.new
	port += 1
	uri = "druby://localhost:#{port}"
	service.uri = uri
	puts "Starting service '#{serverClass.name}: #{uri}"
	DRb.start_service( uri, service )
	services.push uri
}

puts "#{services.length} services started."

services.each {|uri|
	puts "Fetching proxy for service at '#{uri}'"
	obj = DRbObject.new( nil, uri )
	puts "Calling serviceName()"
	puts obj.serviceName
}

puts "Joining the DRb thread"
DRb.thread.join
puts "Joined."

#puts "Joining the thr thread"
#thr.join

