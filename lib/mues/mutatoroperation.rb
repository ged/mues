#!/usr/bin/ruby
# 
# This file contains the Metaclass::MutatorOperation metaclass, which is a
# concrete metaclass for simple mutator (set) operations on a class's
# attributes.
# 
# == Synopsis
# 
#   require 'metaclasses'
#
#	myClass << Metaclass::MutatorOperation.new( 'name' )
# 
# == Rcsid
# 
# $Id: mutatoroperation.rb,v 1.1 2002/03/30 19:04:08 deveiant Exp $
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

require 'metaclass/Operation'

module Metaclass

	### A concrete metaclass for simple mutator (set) operations on a class's attributes.
	class MutatorOperation < Metaclass::Operation

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: mutatoroperation.rb,v 1.1 2002/03/30 19:04:08 deveiant Exp $

		### Create a new MutatorOperation object that sets the instance variable
		### of the name specified by <tt>sym</tt> (a <tt>Symbol</tt> or
		### <tt>String</tt>). If the optional <tt>prelude</tt> argument (a
		### <tt>String</tt>) is given, its contents are integrated into the
		### mutator before the code that sets the target attribute. If the
		### <tt>validTypes</tt> argument is specified (a Class, a String with
		### the name of a Class, or an Array of either Class or Name objects),
		### the mutator will also contains code to check for a valid value via
		### <tt>kind_of?</tt> before the prelude. The <tt>scope</tt> and
		### <tt>visibility</tt> arguments are passed to Metaclass::Operation#new.
		def initialize( sym, validTypes=nil, scope=nil, visibility=nil )
			sym = sym.id2name if sym.is_a? Symbol

			# Assemble the mutator code
			code = <<-END_CODE
			@#{sym} = val
			END_CODE

			# Call the superclass's initializer
			super( sym, code, scope, visibility )

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