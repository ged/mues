#!/usr/bin/ruby -w

if $0 == __FILE__
	raise "This is an include file for the factoryMethods experiment."
end

module Base
	class ExternalService < Base::Service
	end
end


