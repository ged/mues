#!/usr/bin/ruby 

# This is an experiment written to try to figure out why instance variables
# disappear after calling #dup on instances of derivatives of StorableObject.

$LOAD_PATH.unshift ".", "..", "lib", "../lib", "ext", "../ext"

require 'utils'
include UtilityFunctions

require 'mues'

class Foo
	def initialize
		@foo = :something
		@bar = "this"
		@baz = {:that => "a more complex object value"}
	end
	def copy
		duplicate = self.dup
		self.instance_variables.each {|ivar|
			val = eval(ivar)
			$stderr.puts "Copying ivar %s = %s" %
				[ ivar, val.inspect ]
			duplicate.instance_eval("#{ivar} = val")
			#eval("#{name} = val")
		}
		return duplicate
	end
end

class PolyFoo < MUES::PolymorphicObject
	def initialize
		@foo = :something
		@bar = "this"
		@baz = {:that => "a more complex object value"}
	end
	def copy
		duplicate = self.dup
		self.instance_variables.each {|ivar|
			val = eval(ivar)
			$stderr.puts "Copying ivar %s = %s" %
				[ ivar, val.inspect ]
			duplicate.instance_eval("#{ivar} = val")
			#eval("#{name} = val")
		}
		return duplicate
	end
end

class StorableFoo < MUES::StorableObject
	def initialize
		@foo = :something
		@bar = "this"
		@baz = {:that => "a more complex object value"}
	end
	def copy
		duplicate = self.dup
		self.instance_variables.each {|ivar|
			val = eval(ivar)
			$stderr.puts "Copying ivar %s = %s" %
				[ ivar, val.inspect ]
			duplicate.instance_eval("#{ivar} = val")
			#eval("#{name} = val")
		}
		return duplicate
	end
end


header "Experiment: Copy object with ivars."
[ Foo, PolyFoo, StorableFoo ].each {|klass|

	message "Creating original %s object.\n" % klass.name
	original = klass.new

	writeLine
	message "%s = %s\n" % [ klass.name, original.inspect ]
	writeLine

	message "Calling dup.\n"
	original.dup

	writeLine
	message "%s = %s\n" % [ klass.name, original.inspect ]
	writeLine

	message "Making a copy.\n"
	copy = original.copy

	writeLine
	message "Copy of %s (id:%s) = %s\n" % [ klass.name, copy.id, copy.inspect ]
	writeLine

	writeLine
	message "%s (id:%s) = %s\n" % [ klass.name, original.id, original.inspect ]
	writeLine

	print "\n\n"
}

