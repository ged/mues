#!/usr/bin/ruby -w

# Testing mechanism to add class-wide data to a class. This is to work around the
# fact that @@var is a class-wide global, not a class-specific variable.

class Something

	self.instance_eval {
		@instanceVar = 5
	}

	class << self
		def getInstanceVar
			@instanceVar
		end
	end

	attr_accessor :instanceVar
	def initialize( var )
		@instanceVar = var
	end

end

class DerivedSomething < Something

	self.instance_eval {
		@instanceVar = 10
	}


end

puts "Something's instance var: #{Something.getInstanceVar}"
puts "DerivedSomething's instance var: #{DerivedSomething.getInstanceVar}"

e = DerivedSomething.new( 15 )
puts "Instance's instanceVar: #{e.instanceVar}"
puts "Instance's class's instanceVar: #{e.class.getInstanceVar}"

puts "Something's instance var: #{Something.getInstanceVar}"
puts "DerivedSomething's instance var: #{DerivedSomething.getInstanceVar}"

