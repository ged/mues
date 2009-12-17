#!/usr/bin/ruby -w

BEGIN {
	basedir = File::dirname( File::dirname(__FILE__) )
	$LOAD_PATH.unshift basedir
	require 'utils'
	include UtilityFunctions
}

# An experiment to test for the best way to add class methods to an including
# class

header "Experiment: Class Methods Mixin"

module Mixin
	def foo
		return "This is foo"
	end

	def bar
		return "This is bar"
	end

	def self::extend_object( obj )
		unless obj.is_a?( Class )
			raise TypeError, "Cannot extend a #{obj.class}.", caller(1)
		end
		super
	end

	def self::included( klass )
		klass.extend( self )
	end
end

class IncludedFoo
	include Mixin
end

class ExtendedFoo
	extend Mixin
end

try( "IncludedFoo::bar" )
try( "IncludedFoo::foo" )
try( "ExtendedFoo::bar" )
try( "ExtendedFoo::foo" )

try( "Instance methods of IncludedFoo" ) do
	IncludedFoo.instance_methods(false)
end

try( "Instance methods of ExtendedFoo" ) do
	ExtendedFoo.instance_methods(false)
end

try( "to extend an object" ) do
	obj = Object::new
	obj.extend( Mixin )
end




