#!/usr/bin/ruby
# 
# This file contains the MUES::(>>>FILE_SANS<<<) class, a derivative of
# (>>>superclass<<). (>>>description<<<)
# 
# == Synopsis
# 
#   (>>>POINT<<<)
# 
# == Rcsid
# 
# $Id: TEMPLATE.rb.tpl,v 1.7 2002/08/02 14:51:57 deveiant Exp $
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

require 'mues/Mixins'
require 'mues/Object'

module MUES

	### (>>>description<<<)
	class (>>>FILE_SANS<<<) < (>>>superclass<<<)

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
		Rcsid = %q$Id: TEMPLATE.rb.tpl,v 1.7 2002/08/02 14:51:57 deveiant Exp $

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
end # module MUES

>>>TEMPLATE-DEFINITION-SECTION<<<
("description" "File/class description: ")


