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
# $Id: TEMPLATE.rb.tpl,v 1.4 2002/05/26 00:29:49 deveiant Exp $
# 
# == Authors
# 
# * (>>>AUTHOR<<<)
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
		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: TEMPLATE.rb.tpl,v 1.4 2002/05/26 00:29:49 deveiant Exp $

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


