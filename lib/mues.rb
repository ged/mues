#!/usr/bin/ruby
#
# The Multi-User Environment Server.
#
# This module provides a collection of modules, functions, and base classes for
# the Multi-User Environment Server. Requiring it loads all the subordinate
# modules necessary to start the server. 
#
# It also adds four type-checking functions (Object#checkType,
# Object#checkEachType, Object#checkResponse, and Object#checkEachResponse to
# the Ruby <tt>Object</tt> class, defines the <TT>MUES::</TT> namespace, the
# base object class (MUES::Object), and several mixins (MUES::AbstractClass,
# MUES::Debuggable, and MUES::Notifiable).
#
# == Synopsis
#
#   require "mues"
#
#   config = MUES::Config.new( "mues.conf" )
#   MUES::Engine.instance.start( config )
#
# == Rcsid
# 
# $Id: mues.rb,v 1.19 2002/05/28 17:09:17 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Alexis Lee <red@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "md5"
require "sync"

require "mues/Exceptions"


##
# Add a couple of syntactic sugar aliases and an #abstract method to the Module
# class.  (Borrowed from Hipster's component "conceptual script" -
# http://www.xs4all.nl/~hipster/):
#
# [<tt>Module::implements</tt>]
#     An alias for <tt>include</tt>. This allows syntax of the form:
#       class MyClass < MUES::Object; implements MUES::Debuggable, AbstracClass
#         ...
#       end
#
# [<tt>Module::implements?</tt>]
#     An alias for <tt>Module#<</tt>, which allows one to ask
#     <tt>SomeClass.implements?( Debuggable )</tt>.
#
class Module

	##
	# Declare a method as abstract or unimplemented in the current namespace:
	#   abstract :myVirtualMethod, :myOtherVirtualMethod
	# Calling a method declared in this fashion will result in a
	# VirtualMethodError being raised.
	def abstract(*ids)
		for id in ids
			name = id.id2name
			class_eval %Q{
				def #{name}(*a)	 
					raise MUES::VirtualMethodError, "#{name} not implemented"
				end
			}
		end
	end
	
	##
	# Syntactic sugar for mixin/interface modules
	alias :implements :include
	alias :implements? :<
end


##
# Add some type-checking functions to the Object class:
class Object

	#######
	private
	#######

	##
	# Check <tt>anObject</tt> to make sure it's one of the specified
	# <tt>validTypes</tt>. If the object is not one of the specified value
	# types, and an optional block is given it is called with the object being
	# tested and the array of valid types. If no handler block is given, a
	# <tt>TypeError</tt> is raised.
	def checkType( anObject, *validTypes ) # :yields: object, *validTypes
		# Red: Throw away any nil types, and warn
		# Debug level might be inappropriate?
		os = validTypes.size
		validTypes.compact!
		debugMsg(1, "nil given in *validTypes") unless os == validTypes.size
		if validTypes.size > 0 then

			### Compare the object against the array of valid types, and either
			### yield to the error block if given or generate our own exception
			### if not.
			unless validTypes.find {|type| anObject.is_a?( type ) } then
				typeList = validTypes.collect {|type| type.name}.join(" or ")

				if block_given? then
					yield( anObject, [ *validTypes ].flatten )
				else
					raise TypeError, 
						"Argument must be of type #{typeList}, not a #{anObject.class.name}", caller(1)
				end
			end
		else
			if anObject.nil? then
				if block_given? then
					yield( anObject, *validTypes )
				else
					raise ArgumentError, 
						"Argument missing.", caller(1)
				end
			end
		end

		return true
	end


	##
	# Check each object in the specified <tt>objectArray</tt> with a call to
	# #checkType with the specified validTypes array.
	def checkEachType( objectArray, *validTypes, &errBlock ) # :yields: object, *validTypes
		raise ScriptError, "First argument to checkEachType must be an array" unless
			objectArray.is_a?( Array )

		objectArray.each do |anObject|
			if block_given? then
				checkType anObject, validTypes, &errBlock
			else
				checkType( anObject, *validTypes ) {|obj, vTypes|
					typeList = vTypes.collect {|type| type.name}.join(" or ")
					raise TypeError, 
						"Argument must be of type #{typeList}, not a #{obj.class.name}",
						caller(1).reject {|frame| frame =~ /Namespace.rb/}
				}
			end
		end

		return true
	end


	##
	# Check <tt>anObject</tt> for implementations of <tt>requiredMethods</tt>.
	# If one of the methods is unimplemented, and an optional block is given it
	# is called with the method that failed the responds_to? test and the object
	# being checked. If no handler block is given, a <tt>TypeError</tt> is
	# raised.
	def checkResponse( anObject, *requiredMethods ) # yields method, anObject
		# Red: Throw away any nil types, and warn
		# Debug level might be inappropriate?
		os = requiredMethods.size
		requiredMethods.compact!
		debugMsg(1, "nil given in *requiredMethods") unless os == requiredMethods.size
		if requiredMethods.size > 0 then
			requiredMethods.each do |method|
				next if anObject.respond_to?( method )

				if block_given? then
					yield( method, anObject )
				else
					raise TypeError,
						"Argument '#{anObject.inspect}' does not answer the '#{method}()' method", caller(1)
				end
			end
		end

		return true
	end


	##
	# Check each object of <tt>anArray</tt> for implementations of
	# <tt>requiredMethods</tt>, calling the optional <tt>errBlock</tt> if
	# specified, or raising a <tt>TypeError</tt> if one of the methods is
	# unimplemented.
	def checkEachResponse( anArray, *requiredMethods, &errBlock ) # :yeilds: method, object
		raise ScriptError, "First argument to checkEachResponse must be an array" unless
			anArray.is_a?( Array )

		anArray.each do |anObject|
			if block_given? then
				checkResponse anObject, *requiredMethods, &errBlock
			else
				checkResponse( anObject, *requiredMethods ) {|method, object|
					raise TypeError,
						"Argument '#{anObject.inspect}' does not answer the '#{method}()' method",
						caller(1).reject {|frame| frame =~ /Namespace.rb/}
				}
			end
		end

		return true
	end


	##
	# Check the current $SAFE level, and if it is greater than
	# <tt>permittedLevel</tt>, raise a SecurityError.
	def checkSafeLevel( permittedLevel=2 )
		raise SecurityError, "Call to restricted method from insecure space" if
			$SAFE > permittedLevel
		return true
	end

end


##
# The base MUES namespace. All MUES classes live in this namespace.
module MUES

	##
	# A mixin that adds abstractness to a class. Instantiating a class which includes
	# this mixin will result in an InstantiationError.
	module AbstractClass

		### Add a <tt>new</tt> class method to the class which mixes in this
		### module. The method raises an exception if called on the class
		### itself, but not if called via <tt>super()</tt> from a subclass.
		def AbstractClass.append_features( klass )
			klass.class_eval <<-"END"
			class << self
				def new( *args, &block )
					raise InstantiationError if self == #{klass.name}
					super( *args, &block )
				end
			end
			END

			super( klass )
		end
	end


	##
	# An interface that can be implemented by objects (typically, but not necessarily,
	# classes) which need global notification of changes to the Engine^s state outside
	# of the event system. This can be used for initialization and/or cleanup when the
	# event system is not running.
	#
	# The methods which it requires be implemented are:
	#
	# <tt>atEngineStartup( <em>engineObject</em> )</tt>::
	#   This method will be called during engine startup, immediately after the
	#   event subsystem is started. Any returned events will be dispatched from
	#   the Engine.
	#
	# <tt>atEngineShutdown( <em>engineObject</em> )</tt>::
	#   This method will be called just before the engine shuts down, and can be
	#   used to queue critical cleanup events that need to be executed before
	#   the event subsystem is shut down.
	module Notifiable
		@@NotifiableClasses = []

		##
		# Returns an array of classes which implement the MUES::Notifiable interface.
		def Notifiable.classes
			@@NotifiableClasses
		end

		##
		# Add the class which is including us to our array of notifiable classes.
		def Notifiable.append_features( klass )
			@@NotifiableClasses |= [ klass ]
			
			super( klass )
		end

	end


	##
	# A mixin that can be used to add debugging capability to a class and its
	# instances.
	module Debuggable

		##
		# Installs the debugging class methods into the including class.
		def Debuggable.append_features( klass )
			super( klass )

			# Install debug level methods into the calling class along with a
			# class-wide debugging level instance var
			klass.instance_eval( <<-'EOEVAL' )
				@debugLevel = 0

				def debugMsg( level, *messages )
					raise TypeError, "Level must be a Fixnum, not a #{level.class.name}." unless
						level.is_a?( Fixnum )
					return unless debugged?( level )

					logMessage = messages.collect {|m| m.to_s}.join('')
					frame = caller(1)[0]
					if Thread.current != Thread.main && Thread.current.method_defined?( "desc" )
						$stderr.puts "[Thread: #{Thread.current.desc}] #{frame}: #{logMessage}"
					elsif Thread.current != Thread.main
						$stderr.puts "[Thread #{Thread.current.id}] #{frame}: #{logMessage}"
					else
						$stderr.puts "#{frame}: #{logMessage}"
					end

					$stderr.flush
				end

				def debugLevel=( value )
					case value
					when true
						@debugLevel = 1
					when false
						@debugLevel = 0
					when Numeric, String
						value = value.to_i
						value = 5 if value > 5
						value = 0 if value < 0
						@debugLevel = value
					else
						raise TypeError, "Cannot set debugging level to #{value.inspect} (#{value.class.name})"
					end
				end

				def debugLevel
					defined?( @debugLevel ) ? @debugLevel : 0
				end

				def debugged?( level=1 )
					debugLevel() >= level
				end
			EOEVAL
		end

		##
		# Output the specified messages to STDERR if the debugging level for the
		# receiver is at <tt>level</tt> or higher. <em>Alias:</em> _debugMsg
		def debugMsg( level, *messages )
			raise TypeError, "Level must be a Fixnum, not a #{level.class.name}." unless
				level.is_a?( Fixnum )
			return unless debugged?( level )

			logMessage = messages.collect {|m| m.to_s}.join('')
			frame = caller(1)[0]
			if Thread.current != Thread.main then
				$stderr.puts "[Thread #{Thread.current.id}] #{frame}: #{logMessage}"
			else
				$stderr.puts "#{frame}: #{logMessage}"
			end

			$stderr.flush
		end
		alias :_debugMsg :debugMsg

		##
		# Set the debugging level for the receiver to the specified
		# <tt>level</tt>. The <tt>level</tt> may be a <tt>Fixnum</tt> between 0 and 5, or
		# <tt>true</tt> or <tt>false</tt>. Setting the level to 0 or <tt>false</tt> turns
		# debugging off.
		def debugLevel=( value )
			case value
			when true
				@debugLevel = 1
			when false
				@debugLevel = 0
			when Numeric, String
				value = value.to_i
				value = 5 if value > 5
				value = 0 if value < 0
				@debugLevel = value
			else
				raise TypeError, "Cannot set debugging level to #{value.inspect} (#{value.class.name})"
			end
		end

		##
		# Return the debug level of the receiver as a <tt>Fixnum</tt>.
		def debugLevel
			defined?( @debugLevel ) ? @debugLevel : 0
		end

		##
		# Return true if the receiver's debug level is >= 1.
		def debugged?( level=1 )
			debugLevel() >= level || self.class.debugLevel() >= level
		end
	end


	# :TODO: Abstract the pluggability of Environment and CommandShell::Command
	# into a generic mixin.

	# ##
	# # A mixin that can be used to add "pluggability" to an object class by
	# # adding ruby source files to a configured directory.
	# module Extensible
	#
	# 	@@Extensions = {}
	#
	# 	def Extensible.append_features( klass )
	# 		super(klass)
	# 		@@Extensions[klass] = {
	# 			loadTime	=> Time.at(0),
	# 			classes		=> [],
	# 			mutex		=> Sync.new
	# 		}
	#
	# 	end
	# end


	##
	# This class is the abstract base class for all MUES objects. Most of the MUES
	# classes inherit from this.
	class Object < ::Object; implements MUES::AbstractClass

		##
		# Class constants
		Version	= %q$Revision: 1.19 $
		RcsId	= %q$Id: mues.rb,v 1.19 2002/05/28 17:09:17 deveiant Exp $

		##
		# Initialize the object, adding <tt>muesid</tt> and <tt>objectStoreData</tt>
		# attributes to it. Any arguments passed are ignored.
		def initialize( *ignored )
			@muesid = __GenerateMuesId()
			@objectStoreData = nil

			if $DEBUG
				objRef = "%s [%d]" % [ self.class.name, self.id ]
				ObjectSpace.define_finalizer( self, MUES::Object.finalizer(objRef) )
			end
		end

		##
		# Class methods
		class << self

			##
			# Declare a finalizer to keep track of object garbage-collection.
			def finalizer( objDesc ) #  :TODO: This shouldn't be left in a production server.
				return Proc.new {
					if Thread.current != Thread.main
						$stderr.puts "[Thread #{Thread.current.desc}]: " + objDesc + " destroyed."
					else
						$stderr.puts "[Main Thread]: " + objDesc + " destroyed."
					end
				}
			end
		end


		######
		public
		######

		##
		# Fetch the object id assigned by the MUES to this object.
		attr_reader :muesid

		##
		# Return the ObjectStore data of the object. This is an attribute that can be
		# used by the ObjectStore adapters to store meta-data about the object, such
		# as its rowid.
		attr_accessor :objectStoreData

		##
		# Callback method for prepping the object for storage in an ObjectStore.
		def lull
			# No-op
		end

		##
		# Callback method for thawing after being retrieved from the ObjectStore.
		def awaken
			# No-op
		end

		### Allows shallow references to be seen for what they are.
		def shallow?
			false
		end


		#######
		private
		#######

		##
		# Can be used to get a reference to the running server
		# object. Restricted to non-tainted objects running with a
		# <tt>$SAFE</tt> level higher than 3.
		def engine
			raise SecurityError, "Unauthorized request for engine instance." if self.tainted? || $SAFE >= 3
			return MUES::Engine.instance
		end


		##
		# Returns a unique id for an object
		def __GenerateMuesId
			raw = "%s:%s:%.6f" % [ $$, self.id, Time.new.to_f ]
			return MD5.new( raw ).hexdigest
		end
	end


end



