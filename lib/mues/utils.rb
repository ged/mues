#!/usr/bin/ruby
# 
# This file contains various miscellaneous utility functions and builtin class
# extensions.
# 
# == Synopsis
# 
#   require 'mues/utils'
# 
# == Subversion ID
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#


### A couple of syntactic sugar aliases for the Module class.
###
### [<tt>Module::implements</tt>]
###     An alias for <tt>include</tt>. This allows syntax of the form:
###       class MyClass < MUES::Object; implements MUES::Debuggable, AbstracClass
###         ...
###       end
###
### [<tt>Module::implements?</tt>]
###     An alias for <tt>Module#<</tt>, which allows one to ask
###     <tt>SomeClass.implements?( Debuggable )</tt>.
###
class Module

	# Syntactic sugar for mixin/interface modules.  (Borrowed from Hipster's
	# component "conceptual script" - http://www.xs4all.nl/~hipster/)
	alias :implements :include
	alias :implements? :include?
end


### A couple of utility methods for the Class class.
### [<tt>Class::alias_class_method</tt>]
###     Create an alias for a class method. Borrowed from RubyTreasures by Paul
###     Brannan <paul@nospam.atdesk.com>.
class Class

	### Alias a class method.
	def alias_class_method( newSym, oldSym )
		retval = nil
		eval %{
		  class << self
			retval = alias_method :#{newSym}, :#{oldSym}
		  end
		}
	    return retval
	rescue Exception => err
		# Mangle exceptions to point someplace useful
		frames = err.backtrace
		frames.shift while frames.first =~ /#{__FILE__}/
		Kernel::raise err, err.message.gsub(/in `\w+'/, "in `alias_class_method'"), frames
	end
end


### Add some stuff to the String class to allow easy transformation to Regexp
### and in-place interpolation.
class String
	def to_re( casefold=false, extended=false )
		return Regexp::new( self.dup )
	end

	### Ideas for String-interpolation stuff courtesy of Hal E. Fulton
	### <hal9000@hypermetrics.com> via ruby-talk

	### Interpolate any '#{...}' placeholders in the string within the given
	### +scope+ (a Binding object).
    def interpolate( scope )
        unless scope.is_a?( Binding )
            raise TypeError, "Argument to interpolate must be a Binding, not "\
                "a #{scope.class.name}"
        end

		# $stderr.puts ">>> Interpolating '#{self}'..."

        copy = self.gsub( /"/, %q:\": )
        eval( '"' + copy + '"', scope )
	rescue Exception => err
		nicetrace = err.backtrace.find_all {|frame|
			/in `(interpolate|eval)'/i !~ frame
		}
		Kernel::raise( err, err.message, nicetrace )
    end

end


