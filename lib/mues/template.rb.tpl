#!/usr/bin/ruby
# 
# This file contains the MUES::Metaclass::(>>>FILE_SANS<<<) class, a derivative
# of (>>>superclass<<<). (>>>description<<<)
# 
# == Synopsis
# 
#   (>>>POINT<<<)
# 
# == Rcsid
# 
# $Id: template.rb.tpl,v 1.3 2003/10/13 04:02:13 deveiant Exp $
# 
# == Authors
# 
# * (>>>USER_NAME<<<) <(>>>AUTHOR<<<)>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'mues/metaclass/constants'

module MUES
	module Metaclass

		### (>>>description<<<)
		class (>>>FILE_SANS<<<) < (>>>superclass<<<)

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.3 $} )[1]
			Rcsid = %q$Id: template.rb.tpl,v 1.3 2003/10/13 04:02:13 deveiant Exp $

			### Create a new (>>>FILE_SANS<<<) object.
			def initialize
			end


			######
			public
			######


			#########
			protected
			#########


		end # class (>>>FILE_SANS<<<)

	end # module Metaclass
end # module MUES

