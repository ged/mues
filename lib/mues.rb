#!/usr/bin/ruby
#
# The Multi-User Environment Server.
#
# This module provides a collection of modules, functions, and base classes for
# the Multi-User Environment Server. Requiring it loads all the subordinate
# modules necessary to start the server. 
#
# It defines the <tt>MUES</tt> module, the base object class (MUES::Object), and
# several mixins and interface modules (MUES::TypeCheckFunctions,
# MUES::SafeCheckFunctions, MUES::AbstractClass, MUES::Debuggable, and
# MUES::Notifiable).
#
# == Synopsis
#
#   require "mues"
#
#   config = MUES::Config::new( "muesconfig.xml" )
#   MUES::Engine::instance.start( config )
#
# == Rcsid
# 
# $Id: mues.rb,v 1.21 2002/06/06 14:22:23 deveiant Exp $
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
# Add a couple of syntactic sugar aliases to the Module class.  (Borrowed from
# Hipster's component "conceptual script" - http://www.xs4all.nl/~hipster/):
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

	# Syntactic sugar for mixin/interface modules
	alias :implements :include
	alias :implements? :include?
end


##
# The base MUES namespace. All MUES classes live in this namespace.
module MUES

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

		### Add and initialize the @debugLevel of the reciever.
		def initialize( *args ) # :notnew:
			@debugLevel = 0
			super( *args )
		end


		# Returns the current debugging level as a Fixnum. Higher values = more
		# debugging output
		def debugLevel
			@debugLevel ||= 0
		end

		### Set the debugging level of the reciever. The <tt>value</tt> argument
		### can be <tt>true</tt>, <tt>false</tt>, a Numeric, or a String that
		### yields something Numeric when <tt>to_i</tt> is called.
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

		### Returns true if the current debugging level of the reciever is
		### greater than or equal to the specified <tt>level</tt>.
		def debugged?( level=1 )
			debugLevel() >= level
		end


		###############
		module_function
		###############

		### Output <tt>messages</tt> to the debugging log if the
		### <tt>debugLevel</tt> of the calling object is greater than or equal
		### to <tt>level</tt>
		def debugMsg( level, *messages )
			raise TypeError, "Level must be a Fixnum, not a #{level.class.name}." unless
				level.is_a?( Fixnum )
			return unless debugged?( level )

			logMessage = messages.collect {|m| m.to_s}.join('')
			frame = caller(1)[0]
			if Thread.current != Thread.main && Thread.current.respond_to?( :desc )
				logMessage = "[Thread: #{Thread.current.desc}] #{frame}: #{logMessage}"
			elsif Thread.current != Thread.main
				logMessage = "[Thread #{Thread.current.id}] #{frame}: #{logMessage}"
			else
				logMessage = "#{frame}: #{logMessage}"
			end

			$stderr.flush
		end
		alias :_debugMsg :debugMsg
		
	end


	# Mixin that adds some type-checking functions to the current scope
	module TypeCheckFunctions

		###############
		module_function
		###############

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

	end # module TypeCheckFunctions


	##
	# Mixin module that adds some <tt>$SAFE</tt>-level checking functions to the
	# current scope.
	module SafeCheckFunctions

		###############
		module_function
		###############

		##
		# Check the current $SAFE level, and if it is greater than
		# <tt>permittedLevel</tt>, raise a SecurityError.
		def checkSafeLevel( permittedLevel=2 )
			raise SecurityError, "Call to restricted method from insecure space" if
				$SAFE > permittedLevel
			return true
		end

		##
		# Check the current $SAFE level and the taintedness of the current
		# <tt>self</tt>, raising a SecurityError if <tt>$SAFE</tt> is greater
		# than <tt>permittedLevel</tt>, or <tt>self</tt> is tainted.
		def checkTaintAndSafe( permittedLevel=2 )
			raise SecurityError, "Call to restricted code from insecure space" if
				$SAFE > permittedLevel
			raise SecurityError, "Call to restricted code from tainted space" if
				self.tainted?
			return true
		end

	end # module SafeCheckFunctions



	### A mixin module for that adds server functions to the including namespace.
	module ServerFunctions

		###############
		module_function
		###############

		##
		# Fetch running engine object. Restricted to non-tainted objects running
		# with a <tt>$SAFE</tt> level higher than 3.
		def engine
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			return MUES::Engine.instance
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


	# This class is the abstract base class for all MUES objects. Most of the MUES
	# classes inherit from this.
	class Object < ::Object; implements MUES::AbstractClass

		##
		# Class constants
		Version	= %q$Revision: 1.21 $
		RcsId	= %q$Id: mues.rb,v 1.21 2002/06/06 14:22:23 deveiant Exp $

		### Constructor/initializer
		
		# Initialize the object, adding <tt>muesid</tt> and <tt>objectStoreData</tt>
		# attributes to it. Any arguments passed are ignored.
		def initialize( *ignored )
			#__checkVirtualMethods() # <- Not working yet
			@muesid = MUES::Object::generateMuesId( self )

			if $DEBUG
				objRef = "%s [%d]" % [ self.class.name, self.id ]
				ObjectSpace.define_finalizer( self, MUES::Object::makeFinalizer(objRef) )
			end
		end

		###############
		# class methods
		###############

		# Returns a finalizer closure to keep track of object
		# garbage-collection.
		def self.makeFinalizer( objDesc ) #  :TODO: This shouldn't be left in a production server.
			return Proc.new {
				if Thread.current != Thread.main
					$stderr.puts "[Thread #{Thread.current.desc}]: " + objDesc + " destroyed."
				else
					$stderr.puts "[Main Thread]: " + objDesc + " destroyed."
				end
			}
		end

		### Returns a unique id for an object
		def generateMuesId( obj )
			raw = "%s:%s:%.6f" % [ $$, obj.id, Time.new.to_f ]
			return MD5.new( raw ).hexdigest
		end

		######
		public
		######

		# The unique id assigned to the object by the server
		attr_reader :muesid

	end


end


require "mues.so"

