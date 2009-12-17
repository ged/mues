#!/usr/bin/ruby

require "TestServices"
require "drb"

puts "Starting DRuby service"
DRb.start_service()

puts "Getting proxy"
mProxy = DRbObject.new( nil, 'druby://localhost:6565' )

services = []
serviceCount = 0

[ ServiceOne, ServiceTwo, ServiceThree, ServiceFour ].each {|serverClass|
	service = serverClass.new
	puts "Adding service '#{serverClass.name}"
	serviceCount += 1
	serviceName = "service#{serviceCount}"
	mProxy.addService( serviceName, service )
	services.push serviceName
}

anonyclass = <<"EOF"
def serviceName
	return "AnonyService"
end

def shutdown
	return true
end
EOF

puts "Adding service based on anonymous class"
mProxy.addService( "anon", anonyclass )

puts "Calling anon service"
puts mProxy.request( "anon", "serviceName" )

services.each {|name|
	puts "Requesting service '#{name}'"
	puts mProxy.request( name, "serviceName" )
}

puts "Requesting non-existant service 'foo'"
puts mProxy.request( "foo", "foo", "bar" )

services.each {|name|
	puts "Shutting down service '#{name}'"
	mProxy.removeService( name )
}


