#!/usr/local/bin/ruby

# Parse a Ruby source file, building a set of objects
# representing the modules, classes, methods,
# requires, and includes we find (these classes
# are defined in code_objects.rb).

# This file contains stuff stolen outright from:
#
#   rtags.rb - 
#   ruby-lex.rb - ruby lexcal analizer
#   ruby-token.rb - ruby tokens 
#   	by Keiju ISHITSUKA (Nippon Rational Inc.)
#

require "rdoc/rdoc"

module FaerieMUDRDoc

	MY_MODIFIERS =  + [ 'todo' ]

	class Parser < RDoc::Parser
		include RDoc::RubyToken
		include RDoc::TokenStream

		def read_documentation_modifiers(context, allow)
			allow += MY_MODIFIERS
			dir = read_directive(allow)

			case dir[0]

			when "todo"

			else
				super( context, allow )
			end
		end

    
		# Look for directives in a normal comment block:
		#
		#   #--       - don't display comment from this point forward
		#  
		#   # :include: name
		#             - include the contents of file 'name' here
		#
		# This routine modifies it's parameter

		def look_for_directives_in(context, comment)
			
			comment.gsub!(/^(\s*#\s*):(\w+):\s*(\S+)?\s*\n/) do 
				case $2.downcase
					
				when "todo"
					
					
				else
					super( context, comment )
				end
			end
			
			remove_private_comments(comment)
		end
		
	end # class Parser

end # module FaerieMUDRDoc
