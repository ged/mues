#!/usr/bin/ruby -w

# This is an experiment to determine the best way to implement the Command
# objects -- we need to be able to pass in the body of one of the object's
# methods when it is constructed, so that the initializer adds a singleton
# 'invoke' method to the object immediately after instantiation.

class Command

	def initialize( name, &body )
		@name = name
		@body = body

		# This doesn't work because body is no longer in scope after class << self
		#class << self
		#	define_method( :invoke, body )
		#end
	end

	def invoke( *args )
		@body.call( *args )
	end
end


c1 = Command::new( "foo" ) {|*args| puts "Foo command: #{args.inspect}"}
c1.invoke( "Args" )

