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
# MUES::SafeCheckFunctions, MUES::AbstractClass, MUES::Debuggable,
# MUES::FactoryMethods, and MUES::Notifiable).
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
# $Id: mues.rb,v 1.23 2002/08/01 00:42:25 deveiant Exp $
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

unless RUBY_VERSION >= "1.7.2" || ENV['NO_VERSION_CHECK']
	raise RuntimeError, "MUES requires at least Ruby 1.7.2. This is #{RUBY_VERSION}."
end

require 'md5'
require 'sync'
require 'log4r/logger'

require 'mues/Exceptions'

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

	# Predeclare the log class so it can be referred to without loading --
	# breaks mutual dependency loop.
	class Log < Log4r::Logger
	end


	# A version class that understands x.y.z versions, and can do comparisons
	# between them.
	class Version
		
		include Comparable

		### Create and return a new Version object from the specified
		### <tt>version</tt> (a String).
		def initialize( version )
			version = version.to_s

			@versionVector = version.split(/\./).collect {|point|
				point.to_i.chr
			}.join("")
		end


		######
		public
		######

		# The internal representation of the version
		attr_reader :versionVector

		### Comparable method.
		def <=>( otherVersion )
			return nil unless otherVersion.kind_of?( MUES::Version )
			return @versionVector <=> otherVersion.versionVector
		end

		### Return the version as a String
		def to_s
			return @versionVector.split('').collect {|c| c[0].to_s}.join(".")
		end
	end



	# A mixin that adds abstractness to a class. Instantiating a class which includes
	# this mixin will result in an InstantiationError.
	module AbstractClass

		### Add a <tt>new</tt> class method to the class which mixes in this
		### module. The method raises an exception if called on the class
		### itself, but not if called via <tt>super()</tt> from a subclass.
		def self.included( klass )
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
		def self.classes
			@@NotifiableClasses
		end

		##
		# Add the class which is including us to our array of notifiable classes.
		def self.included( klass )
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

			self.log.debug( logMessage )
		end

		# Backward-compatibility alias
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
			validTypes.flatten!
			validTypes.compact!

			unless validTypes.empty?

				### Compare the object against the array of valid types, and either
				### yield to the error block if given or generate our own exception
				### if not.
				unless validTypes.find {|type| anObject.kind_of?( type ) } then
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
							caller(1).reject {|frame| frame =~ /mues.rb/}
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
			raise SecurityError, "Call to restricted code with tainted receiver" if
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



	### A mixin that adds factory class methods to a base class, so that
	### subclasses may be instantiated by name.
	module FactoryMethods

		### Inclusion callback -- Adds the factory methods to the including
		### class.
		def self.included( klass )
			subtype = nil

			MUES::Log.debug { "FactoryMethods: Included in %s" % klass.name }

			# Figure out the parts of the class name we'll need later
			if klass.name =~ /^.*::(.*)/
				subtype = $1
			else
				subtype = klass.name
			end

			MUES::Log.debug { "Adding FactoryMethods to #{klass.inspect} for #{subtype} objects" }

			# Eval the stuff that needs strict scoping in a string instead of a
			# code block so each class gets its own @@registeredDerivatives and
			# subtype value.
			klass.instance_eval %Q{
				@@registeredDerivatives = {}

				### Returns an Array of registered derivatives
				def self.getDerivativeClasses
					@@registeredDerivatives.values.uniq
				end

				### Returns the type name used when searching for a derivative.
				def self.factoryType
					return "#{subtype}"
				end

			}

			# Add a class global to hold derivative classes by various keys and
			# the class methods.
			klass.instance_eval {

				### Given the <tt>className</tt> of the class to instantiate,
				### and other arguments bound for the constructor of the new
				### object, this method loads the derivative class if it is not
				### loaded already (raising a LoadError if an
				### appropriately-named file cannot be found), and instantiates
				### it with the given <tt>args</tt>. The <tt>className</tt> may
				### be the the fully qualified name of the class, the class
				### object itself, or the non-unique part of the class name. The
				### following examples would all try to load an instantiate a
				### class called "MUES::FooListener" if MUES::Listener included
				### MUES::FactoryMethods (which it does):
				###   obj = MUES::Listener::create( 'MUES::FooListener' )
				###   obj = MUES::Listener::create( MUES::FooListener )
				###   obj = MUES::LIstener::create( 'Foo' )
				### If the including class responds to a method called
				### <tt>beforeCreation</tt>, it will be called after the
				### subclass is looked up, but before it is instantiated,
				### passing the subclass, the <tt>className</tt> argument, and
				### the argument array. If the class responds to a method called
				### <tt>afterCreation</tt>, it will be called after the object
				### is instantiated, and is passed the new instance.
				def self.create( subType, *args )
					subClass = getSubclass( subType )

					if self.respond_to?( :beforeCreation )
						# :TODO: Use return values?
						self.beforeCreation( subClass, subType, *args )
					end

					instance = subClass.new( *args )

					if self.respond_to?( :afterCreation )
						# :TODO: Use return values?
						self.afterCreation( instance, *args )
					end

					return instance
				end


				### Inheritance callback -- registers classes which inherit from
				### the Factory for later lookup. This is how the factory class
				### finds the classes named by the #create method. The hash of
				### loaded subclasses can be found in the class variable
				### '@@registeredDerivatives'.
				def self.inherited( subClass )
					factoryType = self.factoryType
					truncatedName =
						if subClass.name.match( /(?:.*::)?(\w+)(?:#{factoryType})/ )
							Regexp.last_match[1]
						else
							subClass.name.sub( /.*::/ )
						end
					

					MUES::Log.debug {
						"Registering the %s %s class as %s" % [
							subClass.name,
							factoryType,
							truncatedName
						]
					}

					@@registeredDerivatives[ subClass.name ] = subClass
					@@registeredDerivatives[ truncatedName ] = subClass
					@@registeredDerivatives[ subClass ] = subClass
				end


				### Given a <tt>className</tt> like that of the first argument
				### to #create, attempt to load the corresponding class if it is
				### not already loaded and return the class object.
				def self.getSubclass( className )
					unless @@registeredDerivatives.has_key? className
						self.loadDerivative( className )
					end
					
					return @@registeredDerivatives[ className ]
				end


				### Calculates an appropriate filename for the derived class
				### using the name of the base class and tries to load it via
				### <tt>require</tt>. If the including class responds to a
				### method named <tt>derivativeDirs</tt>, its return value
				### (either a String, or an array of Strings) is added to the
				### list of prefix directories to try when attempting to require
				### a modules. Eg., if <tt>class.derivativeDirs</tt> returns
				### <tt>['foo','bar']</tt> the require line is tried with both
				### <tt>'foo/'</tt> and <tt>'bar/'</tt> prepended to it.
				def self.loadDerivative( className )
					className = className.to_s
					factoryType = self.factoryType

					MUES::Log.debug {"%s: (%s Factory): loadDerivative( %s )" % [
							self.name, factoryType, className
						]}

					if className =~ /\w+#{factoryType}/
						modName = className.sub( /(?:.*::)?(\w+)(?:#{factoryType})?/,
												"\1#{factoryType}" )
					else
						modName = "%s#{factoryType}" % className
					end

					# See if we have a special subdir that derivatives live in
					if ( self.respond_to?(:derivativeDirs) && (subdirs = self.derivativeDirs) )
						subdirs = subdirs.to_a
					else
						subdirs = ['']
					end

					subdirs.each {|subdir|
						modPath = File::join( subdir, modName )

						MUES::Log.debug {
							%Q{Trying to load '%s' %s with 'require "%s"'} % [
								className,
								factoryType,
								modPath
							]
						}

						# Try to require the module that defines the specified
						# listener
						begin
							require( modPath )
						rescue LoadError => e
							MUES::Log.warn "No module at '#{modPath}'."
						rescue ScriptError,StandardError => e
							MUES::Log.error "Found '#{modPath}', but encountered an error:\n" +
								"    #{e.message} at #{e.backtrace[0]}"
						else
							MUES::Log.info "Successfully loaded '#{modPath}'"
							break
						end
					}

					# Check to see if the specified listener is now loaded. If it
					# is not, raise an error to that effect.
					unless @@registeredDerivatives.has_key? className
						raise RuntimeError,
							"Couldn't find a %s named '%s'" % [
							factoryType,
							className
						], caller(2)
					end
					
					return true
				end
			}

			super( klass )
		end

	end


	# This class is the abstract base class for all MUES objects. Most of the MUES
	# classes inherit from this.
	class Object < ::Object; implements MUES::AbstractClass

		##
		# Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.23 $ )[1]
		Rcsid = %q$Id: mues.rb,v 1.23 2002/08/01 00:42:25 deveiant Exp $

		### Class methods
		def self.version
			return MUES::Version::new( Version )
		end

		### Constructor/initializer
		
		# Initialize the object, adding <tt>muesid</tt> and <tt>objectStoreData</tt>
		# attributes to it. Any arguments passed are ignored.
		def initialize( *ignored )
			# checkVirtualMethods() # <- Not working yet
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
					MUES::Log.debug {"[Thread #{Thread.current.desc}]: " + objDesc + " destroyed."}
				else
					MUES::Log.debug {"[Main Thread]: " + objDesc + " destroyed."}
				end
			}
		end


		### Returns a unique id for an object
		def self.generateMuesId( obj )
			raw = "%s:%s:%.6f" % [ $$, obj.id, Time.new.to_f ]
			return MD5.new( raw ).hexdigest
		end


		######
		public
		######

		# The unique id generated for the object by the constructor
		attr_reader :muesid


		### Comparison operator: Check for object equality using the
		### <tt>other</tt> object's muesid.
		def ==( other )
			return false unless other.kind_of? MUES::Object
			self.muesid == other.muesid
		end



		#########
		protected
		#########

		### Return the logger for the receiving class.
		def log
			MUES::Log[ self.class.name ] || MUES::Log::new( self.class.name )
		end
	end


end

# Now require the stuff that's dependant on this module, but need to be loaded
# with this one.
require "mues.so"
require 'mues/Log'
require 'mues/Engine'

