#!/usr/bin/ruby -w

require "../utils.rb"
include UtilityFunctions

# This is a little experiment to try out some method trickery with Ruby's
# Class#method method.

class Test

	def self.redefineMethods
		self.module_eval %q{
			def publicMethod( *args )
				puts "(Public 2): #{args.inspect}"
			end

			protected

			def protectedMethod( *args )
				puts "(Protected 2): #{args.inspect}"
			end

			private

			def privateMethod( *args )
				puts "(Private 2): #{args.inspect}"
			end
		}
	end

	def self.removeMethods
		self.module_eval %q{
			undef_method :publicMethod
			undef_method :protectedMethod
			undef_method :privateMethod
		}
	end

	# Method-fetcher

	def getMethod( sym )
		method( sym )
	end

	def rescueTest( arg )
		raise "Argument was odd!" if (arg % 2).nonzero?
		puts "Argument was even"
	rescue StandardError => e
		puts "Rescued an error: #{e.message}"
	end

	# Original instance methods

	def publicMethod( *args )
		puts "(Public): #{args.inspect}"
	end

	protected

	def protectedMethod( *args )
		puts "(Protected): #{args.inspect}"
	end

	private

	def privateMethod( *args )
		puts "(Private): #{args.inspect}"
	end

end


header "Creating a test object: "
t = Test::new
puts t.inspect

header "Getting method objects for all three methods: "
methods = [:publicMethod, :protectedMethod, :privateMethod].collect {|sym|
	t.getMethod( sym )
}
puts methods.inspect

header "Redefining methods: "
Test::redefineMethods()
puts "done."

header "Methods are now: "
puts methods.inspect

header "Calling all three methods: "
methods.each {|meth|
	meth.call( "foo" )
}
puts "done."

header "Removing methods: "
Test::removeMethods()
puts "done."

header "Methods are now: "
puts methods.inspect

header "Calling all three methods: "
methods.each {|meth|
	meth.call( "foo" )
}
puts "done."

header "Getting method binding for the rescue test: "
rm = t.getMethod( :rescueTest )
puts rm.inspect

header "Calling rescue method object with even arg: "
rm.call( 4 )
puts "done."

header "Calling rescue method object with even arg: "
rm.call( 5 )
puts "done."

