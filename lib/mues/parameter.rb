#!/usr/bin/ruby
# 
# This file contains the MUES::Metaclass::Parameter class, which is used to
# represent data about an operation argument or parameterized association.
# 
# == Synopsis
# 
#   
# 
# == Rcsid
# 
# $Id: parameter.rb,v 1.3 2002/10/04 09:56:45 deveiant Exp $
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

require 'mues/Mixins'
require 'mues/metaclass/Constants'

module MUES
	module Metaclass

		### A Parameter metaclass -- used to represent data about an operation argument
		### or parameterized association.
		class Parameter

			include MUES::TypeCheckFunctions

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.3 $} )[1]
			Rcsid = %q$Id: parameter.rb,v 1.3 2002/10/04 09:56:45 deveiant Exp $

			### Create and return new Parameter object with the specified +name+. If
			### <tt>validTypes</tt> is a Class, a Metaclass::Class, the name of a
			### class as a String, or an Array of any of these things, they will be
			### used to build type-checking code for the parameter when it is used
			### in code-generation. If a +default+ is specified (which should be a
			### String containing the evalable default), the parameter will be
			### marked as optional, and will default to the specified value.
			def initialize( name, validTypes=[], default=nil )
				name = name.id2name if name.is_a? Symbol

				# Check to be sure the valid types array contains stuff we know how
				# to deal with
				validTypes = [ validTypes ] unless validTypes.is_a?( Array )
				checkEachType( validTypes, ::Class, Metaclass::Class, String, NilClass )

				@name = name
				@validTypes = validTypes
				@default = default
			end


			######
			public
			######

			# The name of the parameter
			attr_reader :name

			# The array of valid types for the parameter
			attr_reader :validTypes
			alias :valid_types :validTypes

			# The parameter's default code (if any).
			attr_reader :default


			### Build and return any type-checking code necessary for this
			### parameter, given its <tt>validTypes</tt>. The returned code will be
			### an Array of Strings.
			def buildCheckCode
				return [] if @validTypes.empty?
				code = ''

				if @validTypes.length > 1
					typeList = @validTypes.collect {|vtype|
						case vtype
						when String
							vtype

						when ::Class, Metaclass::Class
							vtype.name

						else
							raise TypeError,
								"Unhandled parameter type '%s' specified for %s" %
								[ vtype.class.name, @name ]
						end
					}

					code = <<-"EndOfCode"
					raise TypeError, "#@name argument must be one of "+
						"[#{typeList.join(', ')}], not a \#{#@name.class.name}" unless
						[#{typeList.join(', ')}].find {|k| k === #@name}}
					EndOfCode
					code.gsub!( /^\t+/, '' )

				else
					typeName = ''

					case @validTypes[0]
					when String
						typeName = @validTypes[0]

					when ::Class, Metaclass::Class
						typeName = @validTypes[0].name

					else
						raise TypeError,
							"Unhandled parameter type '%s' specified for %s" %
							[ @validTypes[0].class.name, @name ]
					end

					code = "raise TypeError, \"argument '%s' must be a %s\" "\
						"unless %s.kind_of?( %s )" % [
						@name,
						typeName,
						@name,
						typeName
					]
				end

				return code
			end


			#########
			protected
			#########

		end # class Parameter


	end # module Metaclass
end # module MUES
