#!/usr/bin/ruby
# 
# This file contains the MUES::Object and MUES::Version classes. MUES::Object is
# the base class for all objects in MUES. MUES::Version is a Comparable version
# object class that is used to represent class versions.
# 
# == Synopsis
# 
#   require 'mues/object'
#
#   module MUES
#     class MyClass < MUES::Object
#       def initialize( *args )
#         super()
#       end
#     end
#   end
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

require 'digest/md5'
require 'sync'

require 'mues/utils'
require 'mues/exceptions'
require 'mues/mixins'
require 'mues/logger'

module MUES

	# A version class that understands x.y.z versions, and can do comparisons
	# between them.
	class Version
		
		include Comparable

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		### Create and return a new Version object from the specified
		### <tt>version</tt> (a String).
		def initialize( version )
			if version =~ /\./
				parts = version.to_s.split(/\./, 4)
			else
				version = Integer( version )
				parts = version/1000, (version%1000) / 100, (version%100)
			end
			
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

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Returns a MUES::Version object that represents the class's version.
		def self::version
			ver = nil

			if self.const_defined?( :SVNRev )
				rev = self.const_get( :SVNRev )
				ver = if rev.match( /(\d+)/ ) then $1 else 0 end
			elsif self.const_defined?( :Version )
				ver = self.const_get( :Version )
				MUES::Logger[self].info "Deprecated 'Version' constant"
			else
				ver = "0.01"
			end

			return MUES::Version::new( ver )
		end

		
		### Returns a finalizer closure to keep track of object
		### garbage-collection.
		def self::makeFinalizer( objDesc )
			return Proc.new {
				if Thread.current != Thread.main
					MUES::Logger.debug "[Thread #{Thread.current.desc}]: " + objDesc + " destroyed."
				else
					MUES::Logger.debug "[Main Thread]: " + objDesc + " destroyed."
				end
			}
		end

		
		### Returns a unique id for an object
		def self::generateMuesId( obj )
			raw = "%s:%s:%.6f" % [ $$, obj.object_id, Time.new.to_f ]
			return Digest::MD5::hexdigest( raw )
		end


		### Create a method that warns of deprecation for an instance method. If
		### <tt>newSym</tt> is specified, the method is being renamed, and this
		### method acts like an <tt>alias_method</tt> that logs a warning; if
		### not, it is being removed, and the target method will be aliased to
		### an internal method and wrapped in a warning method with the original
		### name.
		def self::deprecate_method( oldSym, newSym=oldSym )
			warningMessage = ''

			# If the method is being removed, alias it away somewhere and build
			# an appropriate warning message. Otherwise, just build a warning
			# message.
			if oldSym == newSym
				newSym = ("__deprecated_" + oldSym.to_s + "__").intern
				warningMessage = "%s#%s is deprecated" %
					[ self.name, oldSym.to_s ]
				alias_method newSym, oldSym
			else
				warningMessage = "%s#%s is deprecated; use %s#%s instead" %
					[ self.name, oldSym.to_s, self.name, newSym.to_s ]
			end
			
			# Build the method that logs a warning and then calls the true
			# method.
			class_eval %Q{
				def #{oldSym.to_s}( *args )
					self.log.warning "%s: #{warningMessage}" % caller(1)
					send( #{newSym.inspect}, *args )
				rescue => err
					# Mangle exceptions to point someplace useful
					Kernel::raise err, err.message, err.backtrace[2..-1]
				end
			}
		rescue Exception => err
			# Mangle exceptions to point someplace useful
			frames = err.backtrace
			frames.shift while frames.first =~ /#{__FILE__}/
			Kernel::raise err, err.message, frames
		end


		### Like Object::deprecate_method, but for class methods.
		def self::deprecate_class_method( oldSym, newSym=oldSym )
			warningMessage = ''

			# If the method is being removed, alias it away somewhere and build
			# an appropriate warning message. Otherwise, just build a warning
			# message.
			if oldSym == newSym
				newSym = ("__deprecated_" + oldSym.to_s + "__").intern
				warningMessage = "%s::%s is deprecated" %
					[ self.name, oldSym.to_s ]
				alias_class_method newSym, oldSym
			else
				warningMessage = "%s::%s is deprecated; use %s::%s instead" %
					[ self.name, oldSym.to_s, self.name, newSym.to_s ]
			end
			
			# Build the method that logs a warning and then calls the true
			# method.
			class_eval %Q{
				def self::#{oldSym.to_s}( *args )
					MUES::Logger.warning "%s: #{warningMessage}" % caller(1)
					send( #{newSym.inspect}, *args )
				rescue => err
					# Mangle exceptions to point someplace useful
					Kernel::raise err, err.message, err.backtrace[2..-1]
				end
			}
		end


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Initialize the object, adding <tt>muesid</tt> and <tt>objectStoreData</tt>
		### attributes to it. Any arguments passed are ignored.
		def initialize( *ignored ) # :notnew:
			# checkVirtualMethods() # <- Not working yet
			@muesid = MUES::Object::generateMuesId( self )
			@version = self.class.version

			if $DEBUG
				objRef = "%s [%d]" % [ self.class.name, self.object_id ]
				ObjectSpace.define_finalizer( self, MUES::Object::makeFinalizer(objRef) )
			end
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

		### Return the MUES::Logger object for the receiving class.
		def log
			MUES::Logger[ self.class.name ] || MUES::Logger::new( self.class.name )
		end
	end # class Object

end # module MUES


# Load the C part of MUES::Object
require 'rbconfig'
require "mues.#{Config::CONFIG['DLEXT']}"
