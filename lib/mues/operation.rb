#!/usr/bin/ruby
###########################################################################
=begin

=Operation.rb

== Name

Operation - An operation metaclass

== Synopsis

  require "metaclass/Operation"

  op = Operation.new( "initialize", <<-"EOM" )
    @name = name
    @attrib = attrib

    puts "Initialized"
  end
  EOM

  op.addArgument( name, String, "defaultName" )
  op.addArgument( attrib, [String, Numeric, IO], $stderr )

  classObject.addOperation( "initialize", op )

  # -or-

  eval "#{op.methodDefinition}"

== Description

Instances of this class are object which are useful adding methods to instances
of the "Class" metaclass.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

module MetaClass

	class OperationError < ScriptError; end
	class UndefinedValue ; end

	class Operation < Object

		### Constants
		VISIBILITY_PUBLIC		= 1
		VISIBILITY_PROTECTED	= 2
		VISIBILITY_PRIVATE		= 3

		SCOPE_CLASS				= 1
		SCOPE_INSTANCE			= 2

		DEFAULT_CODE = "raise StandardError, \"Unimplemented method.\""
		DEFAULT_VISIBILITY		= VISIBILITY_PUBLIC
		DEFAULT_SCOPE			= SCOPE_INSTANCE

		UNDEF = UndefinedValue.new

		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: operation.rb,v 1.2 2001/05/14 12:36:59 deveiant Exp $

		attr_accessor :name, :description, :arguments, :code, :visibility, :scope

		### METHOD: initialize( name )
		def initialize( name, code = DEFAULT_CODE, scope = DEFAULT_SCOPE, visibility = DEFAULT_VISIBILITY )
			@name = name
			@code = code
			@visibility = visibility
			@scope = scope
			@arguments = []
			@description = nil
		end

		### METHOD: <=>( otherOperation )
		def <=>( otherOperation )
			val = @scope <=> otherOperation.scope
			val = @visibility <=> otherOperation.visibility	if val == 0
			val = @name <=> otherOperation.name				if val == 0
			val = self.id <=> otherOperation.id				if val == 0
			
			return val
		end

		### METHOD: addArgument( name, validType = nil, default = nil )
		def addArgument( name, validType = nil, default = UNDEF )
			raise TypeError, "validType argument must be one of [Class,String,Array], not a #{validType.inspect}" unless
				[::Class,Class,String,Array,NilClass].find {|k| k === validType}

			unless validType == nil || default == UNDEF
				defaultMatchesType = false
				if validType.is_a?( Array )
					defaultMatchesType = validType.find {|k| k === default}
				elsif validType.is_a?( String )
					defaultMatchesType = default.type.name == validType
				else
					defaultMatchesType = validType === default
				end

				raise OperationError, "Default for argument does not match validType specification" unless defaultMatchesType
			end

			arg = { "name" => name }
			arg["type"] = validType if validType
			arg["default"] = default if default != UNDEF

			@arguments.push arg
		end

		### METHOD: methodDefinition( methodName )
		def methodDefinition( methodName=@name, includeComment=true )
			argList = _methodArgList()
			argCheckCode = _argCheckBlock()

			defLine = "#{methodName}"
			defLine += "( #{argList} )" if argList != ''

			trimmedCode = @code #.gsub( /^\s*/, "" )

			definition = []
			definition << methodComment( defLine ) if includeComment
			if argCheckCode != ''
				definition << [ "def #{defLine}", argCheckCode, trimmedCode, "end" ]
			else
				definition << [ "def #{defLine}", trimmedCode, "end" ]
			end

			if @scope == SCOPE_CLASS
				definition.unshift "class <<self"
				definition.push "end"
			else
				case @visibility
				when VISIBILITY_PROTECTED
					definition << "protected :#{methodName}"
				when VISIBILITY_PRIVATE
					definition << "private :#{methodName}"
				end
			end

			definition << ""

			return definition
		end

		### METHOD: methodComment( definitionLine, name=@name )
		def methodComment( defLine, name = @name )
			modifiers = []

			case @visibility
			when VISIBILITY_PROTECTED
				modifiers << "PROTECTED"
			when VISIBILITY_PRIVATE
				modifiers << "PRIVATE"
			end

			if @scope == SCOPE_CLASS
				modifiers << "CLASS"
			end

			if modifiers.length > 0
				return "### (#{modifiers.join(' ')}) METHOD: #{defLine}"
			else
				return "### METHOD: #{defLine}"
			end
		end

	  protected

		### (PROTECTED) METHOD: _methodArgList
		def _methodArgList
			argStrings = []
			defaultedArgSeen = false

			arguments.each_with_index {|arg, i|
				raise TypeError, "Illegal arg #{i}: Must be a Hash" unless arg.is_a?( Hash )
				raise OperationError, "Argument #{i} is missing a name" unless arg["name"]

				if defaultedArgSeen || arg.has_key?("default")
					argStrings.push "%s = %s" % [ arg["name"], arg["default"].inspect ]
					defaultedArgSeen = true
				else
					argStrings.push arg["name"]
				end
			}

			return argStrings.join(', ')
		end

		### (PROTECTED) METHOD: _argCheckBlock
		def _argCheckBlock
			checkCode = []
			arguments.each_with_index {|arg, i|
				raise TypeError, "Illegal arg #{i}: Must be a Hash" unless arg.is_a?( Hash )
				raise OperationError, "Argument #{i} is missing a name" unless arg["name"]

				next unless arg.key?("type")

				str = _argCheckCode( arg )
				checkCode.push str if str
			}

			return checkCode.join("\n\t")
		end

		### (PROTECTED) METHOD: _argCheckCode( argname )
		def _argCheckCode( arg )
			raise TypeError, "Arg to build string must be a Hash" unless arg.is_a?( Hash )
			raise ArgumentError, "Arg doesn't have a name" unless arg.has_key?("name")
			
			return nil unless arg.has_key?( "type" )

			case arg["type"]
			when String
				return "raise TypeError, \"argument '%s' must be a %s\" unless %s.is_a?( %s )" % [
					arg['name'],
					arg['type'],
					arg['name'],
					arg['type']
				]
			when Array
				if arg["type"].length > 1
					typeArray = "[#{arg['type'].collect {|t| t.name}.join(', ') }]"

					code = "unless #{typeArray}.find {|k| k === #{arg['name']}.type}"
					code += "\n\t\traise TypeError, \"#{arg['name']} must be one of #{typeArray}\""
					code += "\n\tend"
				else
					code = "raise TypeError, \"argument '%s' must be a %s\" unless %s.is_a?( %s )" % [
						arg['name'],
						arg['type'][0].name,
						arg['name'],
						arg['type'][0].name
					]
				end

				return code
			when ::Class
				return "raise TypeError, \"argument '%s' must be a %s\" unless %s.is_a?( %s )" % [
					arg['name'],
					arg['type'].name,
					arg['name'],
					arg['type'].name
				]
			else
				raise TypeError, "Unhandled type '#{arg['type'].type.inspect}' specified for #{arg['name']}"
			end

		end

	end
end



if $0 == __FILE__
	op = MetaClass::Operation.new( "unimplemented" )
	op2 = MetaClass::Operation.new( "doSomething", <<-"EOF" )
	iterations.times do
		puts "Look, ma, I'm doin' something!"
	end

	puts "Okay. That's enough for now. Here's my second arg: \#{secondArg}"
	EOF

	op2.addArgument( "iterations", Integer )
	op2.addArgument( "secondArg", String, "the Default Value" )
	op2.addArgument( "unused" )
	op2.addArgument( "unused2", [ Array, Class, String, Fixnum ] )

	puts "Method one:"
	puts op.methodDefinition

	puts

	puts "Method two:"
	puts op2.methodDefinition( "renamedMethod" )
end
