#!/usr/bin/ruby
# 
# This file contains the (>>>FILE_SANS<<<) class: (>>>description<<<).
# 
# == Synopsis
# 
#   (>>>POINT<<<)
# 
# == Rcsid
# 
# $Id: TEMPLATE.rb.tpl,v 1.5 2002/05/26 00:34:58 deveiant Exp $
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

require 'mues'


module MUES

	### (>>>description<<<)
	class (>>>FILE_SANS<<<) < (>>>superclass<<<)

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
		Rcsid = %q$Id: TEMPLATE.rb.tpl,v 1.5 2002/05/26 00:34:58 deveiant Exp $

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


