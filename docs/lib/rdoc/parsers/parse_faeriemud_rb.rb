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
require "rdoc/code_objects"
require "rdoc/parsers/parse_rb"
require "rdoc/parsers/parserfactory"

module RDoc

	### Override the ParserFactory's method for adding new parsers so we can
	### override defaults.
	module ParserFactory
		def parse_files_matching(regexp)
			@@parsers.unshift Parsers.new(regexp, self)
		end
	end

	MY_MODIFIERS = [ 'todo' ]

	class MyRubyParser < RubyParser
		include RDoc::RubyToken
		include RDoc::TokenStream

		extend ParserFactory
		parse_files_matching /\.rbw?$/

		def read_documentation_modifiers(context, allow)
			dir = read_directive(allow + MY_MODIFIERS) or return

			case dir[0]
			when "notnew", "not_new", "not-new"
				context.dont_rename_initialize = true

			when "nodoc"
				context.document_self = false
				if dir[1].downcase == "all"
					context.document_children = false
				end

			when "yield", "yields"
				context.block_params = dir[1]
			when "todo"
				context.todolist << dir[1]
			when "refactor"
				context.refactorlist << dir[1]
			else
				super( context, allow )
			end
		end

	end # class MyRubyParser


	### Add 'todolist' and 'refactorlist' attributes to the CodeObject and
	### AnyMethod classes.
	class CodeObject
		def todolist
			@todolist ||= []
		end
		def refactorlist
			@refactorlist ||= []
		end
	end
	class AnyMethod
		def todolist
			@todolist ||= []
		end
		def refactorlist
			@refactorlist ||= []
		end
	end

end # module RDoc
