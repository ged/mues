#!/usr/bin/ruby -w

# Testing to see whether a class's 'inherited' method is called for inheritance of
# child classes.


class A
	def A.inherited( subclass )
		puts "A was just inherited by #{subclass.name}."
	end
end

class B < A ; end
class C < B ; end
class D < C ; end
class E < D ; end

