#!/usr/bin/ruby

classes = {}

class Class
	alias realNew new 
	private_class_method :realNew

	def new( *args )
		puts "In Class#new: self is #{self.to_s}: (" + self.ancestors.collect {|k| k.name}.join(";") + ")"
		#puts "safeSubClass = '#{safeSubClass}'"
		className = if self.name == '' then "<anonymous class>" else "'#{self.name}'" end
		if $SAFE >= 3 then
			if self <= UnsafeClass then
				raise SecurityError, "Instantiation of restricted class #{className} attempted"
			elsif self.tainted? then
				raise SecurityError, "Unsafe instantiation of tainted class #{className} attempted"
			end
		end

		realNew( *args )
	end
end


class UnsafeClass < Object; end
class SafeSubClass < Object; end
class UnsafeSubClass < UnsafeClass; end
class TaintedClass < Object; end

TaintedClass.taint

module TestSuite

	Thread.abort_on_exception = 1

	[ SafeSubClass, UnsafeSubClass, TaintedClass ].each do |klass|
		thr = Thread.new do
			begin
				testThing = klass.new
			rescue SecurityError => e
				$stderr.puts ">>> Exception caught: #{e.message}: \n\t" + e.backtrace.join("\n\t")
			else
				puts "Created successfully."
			end
		end
		thr.join

		thr = Thread.new do
			$SAFE = 3
			begin
				testThing = klass.new
			rescue SecurityError => e
				$stderr.puts ">>> Exception caught: #{e.message}: \n\t" + e.backtrace.join("\n\t")
			else
				puts "Created successfully."
			end
		end

		thr.join
	end

	thr = Thread.new do
		$SAFE = 3

		thing = Class.new( SafeSubClass )
		thing.taint
		puts "#{thing.to_s}"

		thing.new

		subThing = Class.new( thing )
		puts "#{subThing.to_s}"
	end
	thr.join
end


