#!/usr/bin/ruby
# 
# This file contains the Metaclass::Operation metaclass, which is used to add
# operations to instances of Metaclass::Class.
# 
# == Synopsis
# 
#   require "metaclass/Operation"
#   require "metaclass/Parameter"
# 
#   op = Operation.new( "initialize", <<-'EOM' )
#     @name = name
#     @attrib = attrib
# 
#     puts "Initialized"
#   end
#   EOM
# 
#   op << Metaclass::Parameter::new( 'name', String, "defaultName" )
#   op << Metaclass::Parameter::new( 'attrib', [String, Numeric, IO], $stderr )
# 
#   classObject << op
# 
#   # -or-
# 
#   eval "#{op.methodDefinition}"
# 
# == Rcsid
# 
# $Id: operation.rb,v 1.4 2002/04/11 15:55:23 deveiant Exp $
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

require 'metaclass/Constants'
require 'metaclass/Parameter'

module Metaclass

	### Operation metaclass error exception class.
	class OperationError < ScriptError; end

	### Parameter collision error: raised when two parameters with the same name
	### are added to a Metaclass::Operation. If the second argument to
	### <tt>raise</tt> is a Metaclass::Parameter object, an appropriate error
	### message will be built based on its name.
	class ParameterCollisionError < OperationError

		# Set the default error message based on the type of argument.
		def initialize( msg=nil ) # :nodoc:
			case msg
			when String
				super( msg )

			when Metaclass::Parameter
				super( "Cannot add a second '#{msg.name}' parameter." )

			else
				super( "Cannot add two like-named parameters to an operation." )
			end
		end
	end


	### An operation metaclass
	class Operation

		### Constants
		DEFAULT_CODE = "    raise StandardError, \"Unimplemented method.\""
		DEFAULT_VISIBILITY		= Visibility::PUBLIC
		DEFAULT_SCOPE			= Scope::INSTANCE

		COMMENT_WRAP_WIDTH		= 77

		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: operation.rb,v 1.4 2002/04/11 15:55:23 deveiant Exp $

		
		### Return a new Operation with the specified name. If the code argument
		### is given, it becomes the content of the operation. The scope
		### argument specifies if the operation is to be a method of the class
		### to which it is applied, or to instances of that class. The
		### visibility argument specifies from where it can be called.
		def initialize( name, code=DEFAULT_CODE, scope=DEFAULT_SCOPE, visibility=DEFAULT_VISIBILITY )
			@name = name
			@code = code
			@visibility = visibility
			@scope = scope
			@arguments = []
			@description = nil
		end


		######
		public
		######

		# The name of the operation
		attr_accessor :name

		# The human-readable description of the operation (documentation)
		attr_accessor :description

		# The array of arguments the operations takes
		attr_accessor :arguments

		# The implementation-specific code of the operation
		attr_accessor :code

		# The visibility of the operation (One of the Metaclass::Visibility
		# constants)
		attr_accessor :visibility

		# The scope of the operation (One of the Metaclass::Scope constants)
		attr_accessor :scope


		### Append operator: Appends a parameter to the list of parameters this
		### operation currently has and returns the receiver.
		def <<( param )
			addArgument( param )
			return self
		end


		### <tt>Comparable</tt> interface method. Returns -1, 0, or 1 if this
		### operation should sort higher, the same, or lower than the specified
		### <tt>otherOperation</tt>. In truth, this method will only return '0'
		### if <tt>otherOperation</tt> is the same as the receiver.
		def <=>( otherOperation )
			return (@scope <=> otherOperation.scope).nonzero? ||
				(@visibility <=> otherOperation.visibility).nonzero? ||
				(@name <=> otherOperation.name).nonzero? ||
				self.id <=> otherOperation.id
		end


		### Add an argument to this operation. The +param+ argument can either
		### be a Metaclass::Parameter object, or a parameter name. If +param+ is
		### a Parameter object, the <tt>validTypes</tt> and <tt>default</tt>
		### arguments will be supplied as arguments to
		### Metaclass::Parameter#new. The new Parameter object will be appended
		### to the current #arguments, if any. A
		### Metaclass::ParameterCollisionError will be raised if the new
		### parameter has the same name as one that has already been added.
		def addArgument( param, validTypes=nil, default=nil )
			case param
			when Metaclass::Parameter
				# no-op

			when String, Symbol
				param = Metaclass::Parameter.new( param, validTypes, default )

			else
				raise TypeError, 
					"Illegal first argument type. Expected a Metaclass::Parameter or a String, " +
					"got a #{param.type.name}."
			end

			# Detect parameter collision
			raise ParameterCollisionError, param if
				@arguments.detect {|arg| arg.name == param.name}

			@arguments.push param
		end


		### Delete the specified argument from the operation. The +param+
		### argument can be either a Metaclass::Parameter object or a String
		### which will be taken as the name of the argument to remove.
		def delArgument( param )
			case param
			when Metaclass::Parameter
				@arguments.delete( param )

			when String
				@arguments.delete_if {|arg| arg.name == param}

			else
				raise TypeError, "No implicit conversion to Metaclass::Parameter from #{param.type.name}"
			end
		end


		### Return the operation as a method with the specified
		### <tt>methodName</tt>. If <tt>includeComment</tt> is <tt>true</tt>,
		### the method declaration will be have a leading comment block with the
		### operation's <tt>description</tt>.
		def methodDefinition( methodName=@name, includeComment=true )
			argList = buildMethodArgList()
			argCheckCode = buildArgCheckBlock()

			# Set up the definition line and add any parameters
			defLine = "#{methodName}"
			defLine += "( #{argList} )" if argList != ''

			# Normalize the indent of the code
			code = @code

			# Build the array of source
			definition = []
			definition << buildMethodComment() if includeComment
			if argCheckCode != ''
				definition << "def #{defLine}" << argCheckCode << "\n" << @code << "end"
			else
				definition << "def #{defLine}" << @code << "end"
			end

			# Add scope and visibility code
			if @scope == Scope::CLASS
				definition.unshift "class <<self"

				case @visibility
				when Visibility::PROTECTED
					definition << "protected :#{methodName}"
				else
					definition << "public :#{methodName}"
				end

				definition.push "end"
			else
 				case @visibility
 				when Visibility::PROTECTED
					definition << "protected :#{methodName}"
				when Visibility::PRIVATE
					definition << "private :#{methodName}"
				else
					definition << "public :#{methodName}"
				end
			end

			definition << ""
			return definition
		end


		### Build and return a comment block for the operation derived from the
		### <tt>description</tt>.
		def buildMethodComment
			desc = @description || '(Undocumented)'
			desc = wrap( desc ) if desc.length > COMMENT_WRAP_WIDTH
			return desc.collect {|str| "# " + str}.join("\n")
		end



		#########
		protected
		#########

		### :TODO: Write a text-formatter library (extends String, maybe?) to
		### wrap, indent, etc.

		### Wrap the specified +text+ to the specified +width+. Returns an
		### Array of strings of +width+ or less characters long.
		def wrap( text, width=COMMENT_WRAP_WIDTH )
			workingText = text.dup
			newText = []

			while workingText.length > width
				i = width
				until workingText[i,1] =~ /\s/ do
					raise RuntimeError, "Text is not wrappable to the specified width." if i < 1
					i -= 1
				end 
				newText << workingText[ 0, i ]
				workingText[ 0, i + 1 ] = ''
			end

			newText << workingText
			return newText
		end


		### Build and return the method's argument list code.
		def buildMethodArgList
			argStrings = []
			defaultedArgSeen = false

			arguments.each_with_index {|arg, i|
				if defaultedArgSeen || arg.default
					argStrings.push "%s=%s" % [ arg.name, (arg.default || "nil") ]
					defaultedArgSeen = true
				else
					argStrings.push arg.name
				end
			}

			return argStrings.join(', ')
		end


		### Build and return the method's argument type-checking code
		def buildArgCheckBlock
			return "    " + arguments.collect {|arg| arg.buildCheckCode}.flatten.join("\n    ") + "\n"
		end


	end
end



if $0 == __FILE__
	op = Metaclass::Operation.new( "unimplemented" )
	op.description = "A simple test method with no code."

	op2 = Metaclass::Operation.new( "doSomething", <<-"EOF" )
		iterations.times do
			puts "Look, ma, I'm doin' something!"
		end

		puts "Okay. That's enough for now. Here's my second arg: \#{secondArg}"
	EOF

	op2.description = "A more complex testing method"
	op2.addArgument( "iterations", Integer )
	op2.addArgument( "secondArg", String, '"the Default Value"' )
	op2.addArgument( "unused" )
	op2.addArgument( "unused2", [ Array, Class, String, Fixnum ] )


	puts "Method one:"
	puts op.methodDefinition

	puts

	puts "Method two:"
	puts op2.methodDefinition( "renamedMethod" )
end
