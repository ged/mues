#!/usr/bin/ruby
###########################################################################
=begin

=Class.rb

== Name

Class - A class metaclass

== Synopsis

  

== Description



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "delegate"

require "metaclass/Method"
require "metaclass/Operation"
require "metaclass/Interface"
require "metaclass/Attribute"
require "metaclass/Association"

class Module
	def attr_typechecked_accessor( sym, validTypes )
		raise TypeError, "symbol must be a Symbol or a name" unless sym.is_a?( Symbol ) || sym.is_a?( String )
		raise TypeError, "list of valid types must be an array or class" unless
			validTypes.is_a?( Array ) || validTypes.is_a?( Class ) || validTypes.is_a?( String )

		validTypes = validTypes.to_a
		raise ArgumentError, "must specify at least one valid type." unless validTypes.length > 0

		if validTypes.length > 1
			typeDesc = "a %s, or %s" % [validTypes[0...-1].collect {|k|
					case k
					when Class, MetaClass::Class
						k.name
					when String
						k
					end
				}.join(", "), validTypes[-1].name]
			typesArray = "[ %s ]" % [ validTypes.collect {|k| k.name}.join(", ") ]
		else
			typeDesc = "a #{validTypes.at(0).name}"
			typesArray = "[ #{validTypes.at(0).name} ]"
		end

		if sym.is_a?( Symbol )
			symName = sym.id2name
		else
			symName = sym
			sym = sym.intern
		end
		
		self.class_eval <<-"EOF"
		def #{symName}
			@#{symName}
		end
		def #{symName}=( val )
			unless ([ val.class ] & #{typesArray}).length > 0
					raise TypeError, "#{symName} must be a #{typeDesc}"
			end
		end
		EOF
	end
end

module MetaClass

	class ClassException < ScriptError; end

	class Class < Object

		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: class.rb,v 1.2 2001/05/14 12:36:59 deveiant Exp $

		attr_reader :name, :operations, :attributes, :interfaces, :superclass

		### METHOD: initialize( name, superclass=nil )
		def initialize( name, superclass=nil )
			@name = name
			@operations = {}
			@attributes = {}
			@interfaces = []

			@superclass = superclass
		end

		### (OPERATOR) METHOD: >( otherClass )
		def >( otherClass )
			return true if otherClass.ancestors.find {|k| k == self}
			return false
		end

		### (OPERATOR) METHOD: >=( otherClass )
		def >=( otherClass )
			return true if self == otherClass
			return self > otherClass
		end

		### (OPERATOR) METHOD: <( otherClass )
		def <( otherClass )
			return false unless @superclass
			return true if @superclass.ancestors.find {|k| k == otherClass}
			return false
		end

		### (OPERATOR) METHOD: <=( otherClass )
		def <=( otherClass )
			return true if self == otherClass
			return self < otherClass
		end

		### (OPERATOR) METHOD: <=>( otherClass )
		def <=>( otherClass )
			return 1 unless otherClass.is_a?( Class )
			return 0 if otherClass == self
			return -1 if self < otherClass
			return 1
		end

		### METHOD: inspect
		def inspect
			@name
		end

		### METHOD: ancestors
		def ancestors
			if @superclass
				[ self, @superclass.ancestors ].flatten
			else
				[ self ]
			end
		end

		### METHOD: classDefinition( includeClassDeclaration = true, includeComments = true )
		def classDefinition( includeClassDeclaration = true, includeComments = true )
			decl = []

			### Add interfaces to the declaration
			if @interfaces.length > 0
				decl << "### Interfaces"
			end

			### Add attributes to the declaration
			if @attributes.length > 0
				decl << "### Attributes"
				decl << @attributes.sort {|x,y|
					x[1] <=> y[1]
				}.collect {|attrname,attr|
					if attr.validTypes.length > 0
						"attr_typechecked_accessor :#{attrname}, #{attr.validTypes.inspect}"
					else
						"attr_accessor :#{attrname}"
					end
				}

				decl << ""
			end

			### Add operations to the declaration
			if @operations.length > 0
				decl << "### Operations" if includeComments
				decl << @operations.sort {|x,y|
					x[1] <=> y[1]
				}.collect {|opname,op|
					op.methodDefinition(opname,includeComments)
				}

				decl << ""
			end

			### Add the class declaration part if requested to do so
			if includeClassDeclaration
				if @superclass
					decl.unshift "class #{@name} < #{@superclass.name}"
				else
					decl.unshift "class #{@name}"
				end
				return decl.flatten.join("\n    ") + "\nend\n\n"
			else
				return decl.flatten.join("\n")
			end
		end
	end

end


