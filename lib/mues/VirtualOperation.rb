#!/usr/bin/ruby
# 
# This file contains the Metaclass::VirtualOperation class: an operation
# metaclass that expresses a requirement instead of an implementation.
# 
# == Synopsis
# 
#   require 'metaclass/VirtualOperation'
#
#   interface << Metaclass::VirtualOperation::new( "freeze" )
# 
# == Rcsid
# 
# $Id: VirtualOperation.rb,v 1.1 2002/04/09 06:50:41 deveiant Exp $
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

require 'metaclass/Constants'
require 'metaclass/Operation'


module Metaclass

	### An operation metaclass that contains no implementation
	class VirtualOperation < Metaclass::Operation

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: VirtualOperation.rb,v 1.1 2002/04/09 06:50:41 deveiant Exp $

		DEFAULT_VISIBILITY		= Visibility::PUBLIC
		DEFAULT_SCOPE			= Scope::INSTANCE

		### Create a new VirtualOperation object.
		def initialize( name, scope=DEFAULT_SCOPE, visibility=DEFAULT_VISIBILITY )
			super( name, nil, scope, visibility )
		end


		######
		public
		######

		undef_method :code


		#########
		protected
		#########


	end # class VirtualOperation
end # module Metaclass
