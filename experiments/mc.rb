#!/usr/bin/ruby
#
#  Metaclass test/demo
#
# =Authors
#
# * Alexis Lee <red@FaerieMUD.org>
# * Comments added by Michael Granger <ged@FaerieMUD.org> -- mistakes are
#   entirely my fault.
#

# Add lib directory 
if File.exists? "lib/metaclasses.rb"
	$LOAD_PATH.unshift "lib"
elsif File.exists? "../lib/metaclasses.rb"
	$LOAD_PATH.unshift "../lib"
end

require 'metaclasses.rb'

# Create the 'Cat' class metaclass object
catClass = Metaclass::Class.new( "Cat" )

# Add a @name instance attribute and a @@size class attribute
catClass << Metaclass::Attribute.new("name", String, Metaclass::Scope::INSTANCE)
catClass << Metaclass::Attribute.new("size", Integer, Metaclass::Scope::CLASS)

# Add the 'initialize' method
catClass << Metaclass::Operation.new("initialize", <<-'EOM')
	@name = name
	if @@size
		@@size += 1
	else
		@@size = 1
	end
EOM

# Add an argument to the initialize method
catClass.operations['initialize'].addArgument( :name, String )

# Add a 'to_s' method
catClass << Metaclass::Operation.new("to_s", <<-'EOM')
	return @name
EOM

# Add a 'getSize' class method
catClass << Metaclass::Operation.new("getSize", <<-'EOM', Metaclass::Scope::CLASS)
	return @@size
EOM

# Output the class definition, then instantiate the metaclass object and print
# out some stuff about it.
puts catClass.classDefinition(true, true)
cat = catClass.classObj
puts "--\n", cat.class.instance_methods
puts "--\n", cat.methods.sort
puts "--\n", cat.class_variables
puts "--\n", cat.instance_methods, "--\n"

# Now try instantiating a few...
frisky = cat.new("Frisky")
puts frisky
calvin = cat.new("Calvin")
puts calvin

# Test out the class attribute
puts cat.size

