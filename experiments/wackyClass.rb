#!/usr/bin/ruby -w

require 'pp'

class A
	def test
		puts "This is the old A"
	end
end


20.times {|time|
	klass = Class::new( A ) {
		self.module_eval %{
			def test
				puts "This is the new A (#{time})"
				super
			end
		}
	}

	A = klass
}

puts "A's ancestors"
pp A.ancestors

a = A::new
a.test

