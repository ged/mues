#!/usr/bin/ruby
#################################################################
=begin 

=Namespace.rb

== Name

Namespace.rb - provide base class definitions and namespace

== Synopsis

  require "mues/Namespace"

  module MUES
	class MyBaseClass < Object
	  include AbstractClass
	end

	class MyDerivedClass < MyBaseClass
	  ...
    end
  end

== Description

A collection of modules, functions, and base classes for the Multi-User
Environment Server. Requiring it adds four type-checking functions
((({checkType()})), (({checkEachType()})), (({checkResponse()})), and
(({checkEachResponse()}))) to the Ruby (({Object})) class, defines the
(({MUES::})) namespace, the base object class (((<MUES::Object>))), and several
mixins (((<MUES::AbstractClass>)), ((<MUES::Debuggable>)), and
((<MUES::Notifiable>))).

== Functions
=== Global Functions

The Namespace module adds the following global private functions to the
(({Object})) class.

--- Object::checkType( anObject, *validTypes ) {|anObject, *validTypes| errBlock}

    Check ((|anObject|)) to make sure it^s one of the specified
    ((|validTypes|)), calling the optional ((|errBlock|)) if specified, or
    raising a (({TypeError})) if not.

--- Object::checkEachType( anArray, *validTypes ) {|anObject, validTypes| errBlock}

    Check ((|anObject|)) to make sure it^s one of the specified
    ((|validTypes|)), calling the optional ((|errBlock|)) if specified, or
    raising a (({TypeError})) if not.

--- Object::checkResponse( anObject, *requiredMethods ) {|object,method| errBlock}

    Check ((|anObject|)) for implementations of ((|requiredMethods|)), calling
    the optional ((|errBlock|)) if specified, or raising a (({TypeError})) if
    one of the methods is unimplemented.

--- Object::checkEachResponse( anArray, *requiredMethods ) {|object, method| errBlock}

    Check each object of ((|anArray|)) for implementations of
    ((|requiredMethods|)), calling the optional ((|errBlock|)) if specified, or
    raising a (({TypeError})) if one of the methods is unimplemented.

==== Syntactic Sugar

The Namespace module also adds the following syntactic sugar global functions to
the Module class:

--- Module::implements

    An alias for (({include})). This allows syntax of the form:

      class MyClass < MUES::Object; implements Debuggable, AbstracClass
        ...
      end

--- Module::implements?

      An alias for ((<Module#<>)), which allows one to ask
      (({SomeClass.implements?( Debuggable )})).

--- Module::abstract( *symbols )

    Declares one or more methods with the name specified by the given
    ((|symbols|)) which, when called, will throw a
    ((<MUES::Exceptions|VirtualMethodError>)). This allows the declaration of
    abstract methods ((*en masse*)):

      abstract :start, :stop, :run

== Interfaces/Mixins
=== MUES::Notifiable

An interface that can be implemented by objects (typically, but not necessarily,
classes) which need global notification of changes to the Engine^s state outside
of the event system. This can be used for initialization and/or cleanup when the
event system is not running.

The methods which it requires are:

--- atEngineStartup( engineObject )

	This method will be called during engine startup, immediately after the
	event subsystem is started. Any returned events will be dispatched from the
	Engine.

--- atEngineShutdown( engineObject )

	This method will be called just before the engine shuts down, and can be
	used to queue critical cleanup events that need to be executed before the
	event subsystem is shut down.

=== MUES::Debuggable

A mixin that can be used to add debugging capability to a class and its
instances. The following methods are added to your class when you (({include
MUES::Debuggable})):

--- debugMsg( level, *messages )

	Output the specified ((|messages|)) to STDERR if the debugging level for the
	receiver is at ((|level|)) or higher.

--- debugLevel=( value )

	Set the debugging level for the receiver to the specified ((|level|)). The
	((|level|)) may be a (({Fixnum})) between 0 and 5, the (({true})) value, or
	(({false})). Setting the level to 0 or (({false})) turns debugging off.

--- debugLevel()

	Return the debug level of the receiver as a (({Fixnum})).

--- debugged?

	Return true if the receiver^s debug level is >= 1.

=== MUES::AbstractClass

A mixin that adds abstractness to a class. Instantiating a class which includes
this mixin will result in an InstantiationError.

== Classes
=== MUES::Object

This class is the abstract base class for all MUES objects. Most of the MUES
classes inherit from this.

==== Private Global Functions
--- MUES::Object::registerHandlerForEvents( handlerObject, *eventClasses )

    Register ((|handlerObject|)) to receive events of the specified
    ((|eventClasses|)) or any of their derivatives. See the docs for MUES::Event
    for how to handle events.

--- MUES::Object::engine()

    Returns the engine object.

==== Protected Methods

--- MUES::Object#initialize( *ignored )

    Initialize the object, adding (({muesid})) and (({objectStoreData}))
    attributes to it.

==== Public Methods

--- MUES::Object#awaken

    Restore the object after being stored.

--- MUES::Object#lull

    Prepare the object for storage.

--- MUES::Object#muesid

    Return the muesid of the object.

--- MUES::Object#objectStoreData

    Return the objectStoreData of the object. This is an attribute that can be
    used by the ObjectStore adapters to store meta-data about the object, such
    as its rowid.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

#################################################################

require "md5"
require "sync"

require "mues/Exceptions"

### Borrowed from Hipster's component "conceptual script" -
### http://www.xs4all.nl/~hipster/
class Module
	def abstract(*ids)
		for id in ids
			name = id.id2name
			class_eval %Q{
				def #{name}(*a)	 
					raise VirtualMethodError, "#{name} not implemented"
				end
			}
		end
	end
	
	### Syntactic sugar for mixin/interface modules
	alias :implements :include
	alias :implements? :<
end

### Add some type-checking functions to the Object class
class Object

	### Private functions
	private

	### FUNCTION: checkType( anObject, *validTypes ) {|anObject, *validTypes| errBlock}
	### Check ((|anObject|)) to make sure it's one of the specified
	### ((|validTypes|)), calling the optional ((|errBlock|)) if specified,
	### or raising a (({TypeError})) if not.
	def checkType( anObject, *validTypes )
		# Red: Throw away any nil types, and warn
		# Debug level might be inappropriate?
		os = validTypes.size
		validTypes.compact!
		debugMsg("1", "nil given in *validTypes") unless os == validTypes.size
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
	end


	### FUNCTION: checkEachType( anArray, *validTypes ) {|anObject, validTypes| errBlock}
	### Check ((|anObject|)) to make sure it's one of the specified
	### ((|validTypes|)), calling the optional ((|errBlock|)) if specified,
	### or raising a (({TypeError})) if not.
	def checkEachType( anArray, *validTypes, &errBlock )
		raise ScriptError, "First argument to checkEachType must be an array" unless
			anArray.is_a?( Array )

		anArray.each do |anObject|
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
	end


	### FUNCTION: checkResponse( anObject, *requiredMethods ) {|object,method| errBlock}
	### Check ((|anObject|)) for implementations of ((|requiredMethods|)),
	### calling the optional ((|errBlock|)) if specified, or raising a
	### (({TypeError})) if one of the methods is unimplemented.
	def checkResponse( anObject, *requiredMethods )
		# Red: Throw away any nil types, and warn
		# Debug level might be inappropriate?
		os = requiredMethods.size
		requiredMethods.compact!
		debugMsg("1", "nil given in *requiredMethods") unless os == requiredMethods.size
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
	end


	### FUNCTION: checkEachResponse( anArray, *requiredMethods ) {|object, method| errBlock}
	### Check each object of ((|anArray|)) for implementations of
	### ((|requiredMethods|)), calling the optional ((|errBlock|)) if
	### specified, or raising a (({TypeError})) if one of the methods is
	### unimplemented.
	def checkEachResponse( anArray, *requiredMethods, &errBlock )
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
	end

end


### The base MUES namespace
module MUES

	autoload :Engine, "mues/Engine.rb"

	### MODULE: MUES::AbstractClass
	module AbstractClass
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

	### MODULE: MUES::Notifiable
	### An interface that can be implemented by classes which need global
	### notification of changes to the Engine's state outside of the event
	### system. This can be used for initialization, cleanup, etc. when the
	### event system is not running.
	module Notifiable
		@@NotifiableClasses = []

		def Notifiable.classes
			@@NotifiableClasses
		end

		def Notifiable.append_features( klass )
			@@NotifiableClasses |= [ klass ]
			
			super( klass )
		end

	end


	### MODULE: MUES::Debuggable
	### A mixin that can be used to add debugging functionality to a class and its
	### instances.
	module Debuggable

		### (MODULE) METHOD: append_features( class )
		### Installs two class methods, (({debugLevel})) and (({debugLevel=}))
		### into the including class
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

		### (MIXIN) METHOD: debugMsg( level, *messages )
		### Output the specified messages to STDERR if the debugging level for the
		### receiver is at ((|level|)) or higher.
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

		### (MIXIN) METHOD: debugLevel=( value )
		### Set the debugging level for the receiver to the specified
		### ((|level|)). The ((|level|)) may be a (({Fixnum})) between 0 and 5, or
		### (({true})) or (({false})). Setting the level to 0 or (({false})) turns
		### debugging off.
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

		### (MIXIN) METHOD: debugLevel()
		### Return the debug level of the receiver as a (({Fixnum})).
		def debugLevel
			defined?( @debugLevel ) ? @debugLevel : 0
		end

		### (MIXIN) METHOD: debugged?
		### Return true if the receiver's debug level is >= 1.
		def debugged?( level=1 )
			debugLevel() >= level || self.class.debugLevel() >= level
		end
	end


	# ### MODULE: MUES::Extensible
	# ### A mixin that can be used to add "pluggability" to an object class by
	# ### adding ruby source files to a configured directory.
	# module Extensible
		
	# 	@@Extensions = {}

	# 	def Extensible.append_features( klass )
	# 		super(klass)
	# 		@@Extensions[klass] = {
	# 			loadTime	=> Time.at(0),
	# 			classes		=> [],
	# 			mutex		=> Sync.new
	# 		}

			
	# 	end


	# end


	### (ABSTRACT) CLASS: MUES::Object
	class Object < ::Object; implements AbstractClass

		### Class constants
		Version	= %q$Revision: 1.14 $
		RcsId	= %q$Id: mues.rb,v 1.14 2001/12/06 13:38:25 red Exp $

		class << self
			def finalizer( objDesc )
				return Proc.new {
					if Thread.current != Thread.main
						$stderr.puts "[Thread #{Thread.current.desc}]: " + objDesc + " destroyed."
					else
						$stderr.puts "[Main Thread]: " + objDesc + " destroyed."
					end
				}
			end
		end

		### (PROTECTED) METHOD: initialize( *ignored )
		### Initialize the object, adding (({muesid})) and (({objectStoreData}))
		### attributes to it. Any arguments passed are ignored.
		protected
		def initialize( *ignored )
			@muesid = __GenerateMuesId()
			@objectStoreData = nil
			objRef = "%s [%d]" % [ self.class.name, self.id ]
			#ObjectSpace.define_finalizer( self, MUES::Object.finalizer(objRef) )
		end

		###################################################
		###	P U B L I C   M E T H O D S
		###################################################
		public
		attr_reader :muesid
		attr_accessor :objectStoreData

		### METHOD: lull
		def lull
			# No-op
		end

		### METHOD: awaken
		def awaken
			# No-op
		end

		###################################################
		###	P R I V A T E   M E T H O D S
		###################################################
		private

		### FUNCTION: engine()
		### Can be used to get a reference to the running server object. Restricted 
		def engine
			raise SecurityError, "Unauthorized request for engine instance." if self.tainted? || $SAFE >= 3
			return MUES::Engine.instance
		end


		### FUNCTION: registerHandlerForEvents( anObject, *eventClasses )
		### Register the specified object as being interested in events of the
		### type/s specified by ((|eventClasses|)).
		def registerHandlerForEvents( handlerObject, *eventClasses )
			checkResponse( handlerObject, "handleEvent" )

			eventClasses.each do |eventClass|
				eventClass.RegisterHandlers( handlerObject )
			end
		end


		### (PRIVATE) FUNCTION: __GenerateMuesId
		### Returns a unique id for an object
		def __GenerateMuesId
			raw = "%s:%s:%.6f" % [ $$, self.id, Time.new.to_f ]
			return MD5.new( raw ).hexdigest
		end
	end


end



