#!/usr/bin/ruby
###########################################################################

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
(({MUES::})) namespace, the base object class ((({MUES::Object}))), and a mixin
for abstract classes ((({MUES::AbstractClass}))).

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

###########################################################################

require "md5"
require "mues/Exceptions"

class Object

	### FUNCTION: checkType( anObject, *validTypes )
	def checkType( anObject, *validTypes )
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

	### FUNCTION: checkResponse( anObject, *requiredMethods ) {|method, object| errBlock}
	def checkResponse( anObject, *requiredMethods )
		if requiredMethods.size > 0 then
			requiredMethods.each do |method|
				next if anObject.respond_to?( method )

				if block_given? then
					yield( method, anObject )
				else
					raise TypeError,
						"Argument does not answer the '#{method}()' method", caller(1)
				end
			end
		end
	end

	### FUNCTION: checkEachResponse( anObject, *requiredMethods ) {|method, object| errBlock}
	def checkEachResponse( anArray, *requiredMethods, &errBlock )
		raise ScriptError, "First argument to checkEachResponse must be an array" unless
			anArray.is_a?( Array )

		anArray.each do |anObject|
			if block_given? then
				checkResponse anObject, *requiredMethods, &errBlock
			else
				checkResponse( anObject, *requiredMethods ) {|method, object|
					raise TypeError,
						"Argument #{anObject.to_s} does not answer the '#{method}()' method",
						caller(1).reject {|frame| frame =~ /Namespace.rb/}
				}
			end
		end
	end

end # class Object


module MUES

	### MODULE: MUES::AbstractClass
	module AbstractClass
		def AbstractClass.append_features( klass )
			klass.class_eval <<-"END"
			class << self
				def new( *args, &block )
					raise InstantiationError if self == #{klass.name}
					super
				end
			end
			END
		end
	end

	### (ABSTRACT) CLASS: MUES::Object
	class Object < ::Object
		include AbstractClass

		### Class constants
		Version	= %q$Revision: 1.5 $
		RcsId	= %q$Id: mues.rb,v 1.5 2001/04/06 08:19:20 deveiant Exp $

		### (PROTECTED) METHOD: initialize( *ignored )
		protected
		def initialize( *ignored )
			@muesid = __GenerateMuesId()
			@objectStoreData = nil
		end

		#######################################################################
		###	P U B L I C   M E T H O D S
		#######################################################################
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

		#######################################################################
		###	P R I V A T E   M E T H O D S
		#######################################################################

		### (PRIVATE GLOBAL) FUNCTION: engine()
		### Can be used to get a reference to the running server object. Restricted 
		private
		def engine
			raise SecurityError, "Unauthorized request for engine instance." if self.tainted? || $SAFE >= 3
			
			unless ( Module.constants.detect {|const| const == "Engine"} )
				raise EngineException, "Engine class is not yet loaded" 
			end
			
			return Engine.instance
		end

		### (PRIVATE GLOBAL) METHOD: __GenerateMuesId
		### Returns a unique id for an object
		private
		def __GenerateMuesId
			raw = "%s:%s:%.6f" % [ $$, self.id, Time.new.to_f ]
			return MD5.new( raw ).hexdigest
		end
	end


end



