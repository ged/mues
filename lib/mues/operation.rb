#!/usr/bin/ruby
# 
# This file contains the MUES::Metaclass::Operation metaclass, which is used to
# add operations to instances of MUES::Metaclass::Class.
# 
# == Synopsis
# 
#   require "mues/metaclass/Operation"
#   require "mues/metaclass/Parameter"
#	include MUES
# 
#   op = Metaclass::Operation.new( "initialize", <<-'EOM' )
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
# == Rcsid
# 
# $Id: operation.rb,v 1.7 2002/10/04 05:06:43 deveiant Exp $
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

require 'mues/Mixins'

require 'mues/metaclass/Constants'
require 'mues/metaclass/Parameter'

module MUES
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


		### A metaclass used to add operations to instances of
		### MUES::Metaclass::Class.
		class Operation

			include MUES::TypeCheckFunctions

			### Constants
			DEFAULT_CODE = "    raise StandardError, \"Unimplemented method.\""
			DEFAULT_VISIBILITY		= Visibility::PUBLIC
			DEFAULT_SCOPE			= Scope::INSTANCE

			COMMENT_WRAP_WIDTH		= 77

			Version = /([\d\.]+)/.match( %q{$Revision: 1.7 $} )[1]
			Rcsid = %q$Id: operation.rb,v 1.7 2002/10/04 05:06:43 deveiant Exp $


			### Return a new Operation with the specified name. If the code argument
			### is given, it becomes the content of the operation. The scope
			### argument specifies if the operation is to be a method of the class
			### to which it is applied, or to instances of that class. The
			### visibility argument specifies from where it can be called.
			def initialize( name, code=DEFAULT_CODE, scope=DEFAULT_SCOPE, visibility=DEFAULT_VISIBILITY )
				@name = name
				if code == DEFAULT_CODE
					@code = code
				else
					@code = ' ' * 4 + code.squeeze("\n").strip
				end
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
				checkType( param, Metaclass::Parameter, ::String, ::Symbol )

				if param.kind_of?( ::String ) || param.kind_of?( ::Symbol )
					param = Metaclass::Parameter.new( param, validTypes, default )
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

				when ::String
					@arguments.delete_if {|arg| arg.name == param}

				else
					raise TypeError, "No implicit conversion to Metaclass::Parameter from #{param.class.name}"
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
				indent = nil
				code = @code.
					split( /\s+\n/ ).
					find_all {|line| line =~ /\S/ }.
					collect  {|line| line.gsub( /^\s+/, (' ' * 4) ) }.
					join("\n")

				# Build the array of source
				definition = []
				definition << buildMethodComment() if includeComment
				unless argCheckCode.empty?
					definition << "def #{defLine}" << argCheckCode << code << "end"
				else
					definition << "def #{defLine}" << code << "end"
				end

				# Add scope and visibility code
				if @scope == Scope::CLASS
					case @visibility
					when Visibility::PROTECTED
						definition << "protected :#{methodName}"
					else
						definition << "public :#{methodName}"
					end

					# Add an additional level of indent
					definition.collect! {|line| "    #{line}"}

					definition.unshift "class <<self"
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

				# Add a trailing blank line and return
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


			### Returns true if this method is virtual (ie., has no definition).
			def virtual?
				return @code == DEFAULT_CODE
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
				block = ''

				unless arguments.empty?
					block = "    " + arguments.collect {|arg| arg.buildCheckCode}.flatten.join("")
				end

				return block.strip
			end



			### Mixin module that provides Metaclass::Operation accessor methods and
			### instance variables for classes which include them.
			module Methods

				include MUES::TypeCheckFunctions

				### Initialize @operations and @classOperations instance variables
				### for including classes (or ones that call super(), anyway.
				def initialize( *args ) # :notnew
					@operations			= {}
					@classOperations	= {}

					super( *args )
				end


				######
				public
				######

				# The Hash of operations belonging to instances this class, keyed by name
				attr_reader :operations

				# The Hash of class operations belonging to this class, keyed by name
				attr_reader :classOperations



				### Test for the operation specified. Returns true if instances of the
				### class have an operation with the specified operation, which may be a
				### Metaclass::Operation object, or a String containing the name of the
				### operation to test for.
				def hasOperation?( operation )
					if operation.kind_of? Metaclass::Operation
						return true if @operations.has_value? operation
					else
						return @operations.has_key?( operation.to_s )
					end
				end


				### Test for the class operation specified. Returns true if instances of
				### the class have an operation with the specified operation, which may
				### be a Metaclass::Operation object, or a String containing the name of
				### the operation to test for.
				def hasClassOperation?( operation )
					if operation.kind_of? Metaclass::Operation
						return true if @classOperations.has_value?( operation )
					else
						return @classOperations.has_key?( operation.to_s )
					end
				end

				### Add the specified operation (a Metaclass::Operation object) to the
				### class. If the optional +name+ argument is given, it will be used as
				### the method name instead of the operation's own name. Returns true if the
				### operation was successfully added.
				def addOperation( operation, name=nil )
					MUES::TypeCheckFunctions::checkType( operation, Metaclass::Operation )

					# Normalize the name and set the operation in the appropriate
					# operation hash
					name ||= operation.name
					if operation.scope == Scope::INSTANCE
						@operations[ name ] = operation
					else
						@classOperations[ name ] = operation
					end

					# If the class object's already been instantiated, turn off warnings
					# about redefinition, and eval the new method into the class object
					if self.instance
						oldVerbose = $VERBOSE
						$VERBOSE = false
						self.instance.module_eval { operation.methodDefinition(name) }
						$VERBOSE = oldVerbose
					end

					return true
				end


				### Remove the specified operation (a Metaclass::Operation object, or a
				### String containing the name associated with the operation). Returns
				### the removed operation if successful, or <tt>nil</tt> if the
				### specified operation was not found.
				def removeOperation( operation )
					MUES::TypeCheckFunctions::checkType( operation, Metaclass::Operation, ::String )

					# Look for and remove the specified attribute
					rval = @operations.find {|name,opObj|
						opObj == operation || name == operation
					}

					# If we found the pair, remove them and their associated operations, if present
					if rval
						if self.instance
							self.instance.module_eval { remove_method rval[0].intern }
						end

						rval = @operations.delete( rval[0] )
					end

					return rval
				end


				### Return the code necessary to add the receiver's class operations
				### to the current scope
				def classOperationsDeclaration( includeComments = true )
					decl = []

					unless @classOperations.empty?
						decl << "### Class operations" if includeComments
						decl << @classOperations.sort {|x,y|
							x[1] <=> y[1]
						}.collect {|opname,op|
							op.methodDefinition(opname,includeComments)
						}

						decl << ""
					end

					return decl
				end

				### Return the code necessary to add the receiver's instance
				### operations to the current scope
				def operationsDeclaration( includeComments = true )
					decl = []

					### Add operations to the declaration
					unless @operations.empty?
						decl << "### Operations" if includeComments
						decl << @operations.sort {|x,y|
							x[1] <=> y[1]
						}.collect {|opname,op|
							op.methodDefinition(opname,includeComments)
						}

						decl << ""
					end

					return decl
				end

			end # module Methods

		end # class Operation


	end # module Metaclass
end # module MUES
