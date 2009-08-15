#!/usr/bin/ruby -w

require 'xmp'

class A

	include Comparable
	
	@@count = 0

	def initialize
		@@count += 1
		@myCount = @@count
	end

	attr_reader :myCount

	def <=>( other )
		raise ArgumentError, "Not an A" unless other.is_a? A
		return self.myCount <=> other.myCount
	end
end

class B < A

	def <=>( other )
		raise ArgumentError, "Not a B" unless other.is_a? B
		return self.myCount <=> other.myCount
	end

end


xmp <<"EOF"
a1 = A.new
a2 = A.new
b1 = B.new

a1 <=> a2
a2 <=> a1

a1 > a2
a2 > a1

b1 <=> a1
b1 < a1

EOF
