#!/usr/bin/ruby
# 
# This file contains the MUES::Logger::(>>>class<<<) class, a derivative of
# (>>>superclass<<<). (>>>description<<<)
# 
# == Rcsid
# 
# $Id: TEMPLATE.tb.tpl,v 1.1 2003/11/27 05:45:49 deveiant Exp $
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

(>>>MARK<<<)

module MUES
class Logger

	### (>>>description<<<).
	class (>>>class<<<) < (>>>superclass<<<)

			# CVS version tag
			Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

			# CVS id tag
			Rcsid = %q$Id: TEMPLATE.tb.tpl,v 1.1 2003/11/27 05:45:49 deveiant Exp $


			### Create a new MUES::(>>>class<<<) object.
			def initialize
			end


			######
			public
			######


			#########
			protected
			#########


	end # class (>>>class<<<)

end # class Logger
end # module MUES


>>>TEMPLATE-DEFINITION-SECTION<<<
("class" "Class: MUES::Logger::")
("superclass" "Derives from: ")
("description" "File/class description: ")


