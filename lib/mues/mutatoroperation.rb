#!/usr/bin/ruby
# 
# This file contains the MUES::Metaclass::MutatorOperation metaclass, which is a
# concrete metaclass for simple mutator (set) operations on a class's
# attributes.
# 
# == Synopsis
# 
#   require 'mues/metaclasses'
#	include MUES
#
#	myClass << Metaclass::MutatorOperation.new( 'name' )
# 
# == Rcsid
# 
# $Id: mutatoroperation.rb,v 1.7 2003/10/13 04:02:13 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require 'mues/metaclass/operation'

module MUES
	module Metaclass

		### A concrete metaclass for simple mutator (set) operations on a
		### class's attributes.
		class MutatorOperation < Metaclass::Operation

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.7 $} )[1]
			Rcsid = %q$Id: mutatoroperation.rb,v 1.7 2003/10/13 04:02:13 deveiant Exp $

			### Create a new MutatorOperation object that sets the instance variable
			### of the name specified by <tt>sym</tt> (a <tt>Symbol</tt> or
			### <tt>String</tt>).If the <tt>validTypes</tt> argument is specified (a
			### Class, a String with the name of a Class, or an Array of either
			### Class or Name objects), the mutator will also contains code to check
			### for a valid value via <tt>kind_of?</tt>. The <tt>scope</tt> and
			### <tt>visibility</tt> arguments are passed to
			### Metaclass::Operation#new.
			def initialize( sym, validTypes=nil, scope=Operation::DEFAULT_SCOPE, visibility=Operation::DEFAULT_VISIBILITY )

				# Stringify the symbol and strip any trailing equals
				sym = sym.id2name if sym.is_a? Symbol
				sym.gsub!( /=$/, '' )

				# Assemble the mutator code

				case scope
				when Scope::CLASS
					super( "#{sym}=", "@@#{sym} = val", scope, visibility )
				else
					super( "#{sym}=", "@#{sym} = val", scope, visibility )
				end

				# Add the 'val' argument
				self.addArgument( :val, validTypes )
			end


			######
			public
			######


			#########
			protected
			#########


		end # class MutatorOperation

	end # module Metaclass
end # module MUES

