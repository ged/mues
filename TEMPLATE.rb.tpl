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
# $Id: TEMPLATE.rb.tpl,v 1.1 2002/05/26 00:12:05 deveiant Exp $
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

### (>>>description<<<)
class (>>>FILE_SANS<<<) < (>>>superclass<<<)

	### Class constants
	Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
	Rcsid = %q$Id: TEMPLATE.rb.tpl,v 1.1 2002/05/26 00:12:05 deveiant Exp $

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

