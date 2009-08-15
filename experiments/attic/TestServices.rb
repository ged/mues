#!/usr/bin/ruby

class Service < Object
	def shutdown
		return true
	end
end

class ServiceOne < Service
	def serviceName
		return "Service 1"
	end
end

class ServiceTwo < Service
	def serviceName
		return "Service 2"
	end
end

class ServiceThree < Service
	def serviceName
		return "Service 3"
	end
end

class ServiceFour < Service
	def serviceName
		return "Service 4"
	end
end

