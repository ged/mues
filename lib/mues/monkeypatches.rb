#!/usr/bin/env ruby

# 
# A (hopefully) minimal collection of extensions to core classes.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <mgranger@rubycrafters.com>
# 
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#

### Add some operator methods to regular expression objects for catenation,
### union, etc.
module MUES::RegexpOperators

	### Append the given +other+ Regexp (or String) onto a copy of the receiving
	### one and return it.
	def +( other )
		return self.class.new( self.to_s + other.to_s )
	end

	### Create and return a new Regexp that is an alternation between the
	### receiver and the +other+ Regexp.
	def |( other )
		return Regexp.union( self, other )
	end
end

# Extended with MUES::RegexpOperators
class Regexp # :nodoc:
	include MUES::RegexpOperators
end


### Add some stuff to the String class to allow easy transformation to Regexp
### and in-place interpolation.
module MUES::StringExtensions
	
	### Return the receiving String as a Regexp.
	def to_re( casefold=false, extended=false )
		return Regexp.new( self.dup )
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
		Kernel.raise( err, err.message, nicetrace )
    end

end

# Extended with MUES::StringExtensions
class String # :nodoc:
	include MUES::StringExtensions
end

