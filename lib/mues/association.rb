#!/usr/bin/ruby
# 
# This file contains Metaclass::Association, a class-association metaclass. It
# is used to encapsulate information about the association between two classes
# in a class model.
#
# This class is currently just a placeholder; it isn't used by the other
# metaclasses, but exists here for possible future experimentation with further
# levels of abstraction.
# 
# == Synopsis
# 
#   require "metaclass/Association"
# 
# == Rcsid
#
# $Id: association.rb,v 1.4 2002/04/06 16:59:23 deveiant Exp $
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

require 'metaclass/Constants'

module Metaclass

	autoload :Class, 'metaclass/Class'

	# A class-association metaclass. This class is currently just a placeholder;
	# it isn't used by the other metaclasses, but exists here for possible
	# future experimentation with further levels of abstraction.
	class Association

		# Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: association.rb,v 1.4 2002/04/06 16:59:23 deveiant Exp $

		# This is an abstract class, so prevent it from being instantiated
		private_class_method :new

		### Initialize a new association with the specified name. This method
		### should be called by concrete derivatives.
		def initialize( name ) # :notnew:
			@name = name
		end


		######
		public
		######

		# The name of the association
		attr_accessor :name

	end

end
