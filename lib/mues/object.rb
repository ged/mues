#!/usr/bin/ruby
# 
# This file contains the MUES::Object and MUES::Version classes. MUES::Object is
# the base class for all objects in MUES. MUES::Version is a Comparable version
# object class that is used to represent class versions.
# 
# == Synopsis
# 
#   require 'mues/Object'
#
#   module MUES
#     class MyClass < MUES::Object
#       def initialize( *args )
#         super()
#       end
#     end
#   end
# 
# == Rcsid
# 
# $Id: object.rb,v 1.3 2002/10/13 23:12:30 deveiant Exp $
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

require 'digest/md5'
require 'sync'

###
### Add a couple of syntactic sugar aliases to the Module class.  (Borrowed from
### Hipster's component "conceptual script" - http://www.xs4all.nl/~hipster/):
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

	# Syntactic sugar for mixin/interface modules
	alias :implements :include
	alias :implements? :include?
end

require 'mues/Exceptions'
require 'mues/Mixins'
require 'mues/Log'

module MUES

	# A version class that understands x.y.z versions, and can do comparisons
	# between them.
	class Version
		
		include Comparable

		### Create and return a new Version object from the specified
		### <tt>version</tt> (a String).
		def initialize( version )
			parts = version.to_s.split(/\./, 4)

			@major, @minor, @point, @frag = parts
			@versionVector = parts.collect {|num|
				num.to_i.chr
			}.join("")
		end


		######
		public
		######

		# The internal representation of the version
		attr_reader :versionVector

		# The major (X.y.y.y) version
		attr_reader :major

		# The minor (y.X.y.y) version
		attr_reader :minor

		# The point (y.y.X.y) version (if any)
		attr_reader :point

		# The fragment (y.y.y.X) version (if any)
		attr_reader :frag


		### Comparable method.
		def <=>( otherVersion )
			return nil unless otherVersion.kind_of?( MUES::Version )
			return @versionVector <=> otherVersion.versionVector
		end

		### Return the version as a String
		def to_s
			return @versionVector.split('').collect {|c| c[0].to_s}.join(".")
		end

		### Return the Major.Minor parts of the version as a Floating-point
		### number
		def to_f
			return ("%d.%d" % [@major, @minor]).to_f
		end

		### Returns a string containing a human-readable representation of the
		### version object.
		def inspect
			"Version %s" % self.to_s
		end
	end



	# This class is the abstract base class for all MUES objects. Most of the MUES
	# classes inherit from this.
	class Object < ::Object; implements MUES::AbstractClass

		### Class constants
		Version = /([\d\.]+)/.match( %q{$Revision: 1.3 $} )[1]
		Rcsid = %q$Id: object.rb,v 1.3 2002/10/13 23:12:30 deveiant Exp $


		### Initialize the object, adding <tt>muesid</tt> and <tt>objectStoreData</tt>
		### attributes to it. Any arguments passed are ignored.
		def initialize( *ignored ) # :notnew:
			# checkVirtualMethods() # <- Not working yet
			@muesid = MUES::Object::generateMuesId( self )
			@version = self.class.version

			if $DEBUG
				objRef = "%s [%d]" % [ self.class.name, self.id ]
				ObjectSpace.define_finalizer( self, MUES::Object::makeFinalizer(objRef) )
			end
		end


		###############
		# class methods
		###############

		### Class methods

		### Returns a MUES::Version object that represents the class's version.
		def self.version
			ver = nil

			if self.const_defined?( :Version )
				ver = self.const_get( :Version )
			else
				ver = "0.01"
			end

			return MUES::Version::new( ver )
		end

		
		### Returns a finalizer closure to keep track of object
		### garbage-collection.
		def self.makeFinalizer( objDesc ) #  :TODO: This shouldn't be left in a production server.
			return Proc.new {
				if Thread.current != Thread.main
					MUES::Log.debug {"[Thread #{Thread.current.desc}]: " + objDesc + " destroyed."}
				else
					MUES::Log.debug {"[Main Thread]: " + objDesc + " destroyed."}
				end
			}
		end


		### Returns a unique id for an object
		def self.generateMuesId( obj )
			raw = "%s:%s:%.6f" % [ $$, obj.id, Time.new.to_f ]
			return Digest::MD5::hexdigest( raw )
		end


		######
		public
		######

		### The unique id generated for the object by the constructor
		attr_reader :muesid

		### The version number (a MUES::Version object) of the class from which
		### the object was instantiated
		attr_reader :version


		### Comparison operator: Check for object equality using the
		### <tt>other</tt> object's muesid.
		def ==( other )
			return false unless other.kind_of? MUES::Object
			self.muesid == other.muesid
		end


		#########
		protected
		#########

		### Return the MUES::Log logger object for the receiving class.
		def log
			MUES::Log[ self.class.name ] || MUES::Log::new( self.class.name )
		end
	end # class Object

end # module MUES


# Load the C part of MUES::Object
require "mues.so"
