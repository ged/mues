#!/usr/bin/ruby -w

# Testing to see whether a class's 'inherited' method is called for inheritance of
# child classes.


class A
	def self::bar
		puts "BAR!"
	end

	def self::inherited( subclass )
		puts "A was just inherited by #{subclass.name}."
	end
end

class B < A ; end
class C < B ; end
class D < C ; end
class E < D ; end
class F < E 
	def self::bar
		super
		puts "E-BAR!"
	end
end

E.bar
F.bar 

# A was just inherited by B.
# A was just inherited by C.
# A was just inherited by D.
# A was just inherited by E.
# A was just inherited by F.
# BAR!
# BAR!
# E-BAR!
