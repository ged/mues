#
# This is a hacked-over collection of subclasses that override the default RDoc
# ones for the purpose of adding more syntax-markup to the HTML of the source
# code views, doing tab-expansion, HTML entity escaping, etc.
#
# == Rcsid
# 
# $Id: faeriemud_generator.rb,v 1.1 2002/03/30 19:01:10 deveiant Exp $
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


require "rdoc/generators/html_generator"

module Generators

  ##
  # Override the regular ContextUser module so the collect_methods() method can be overridden.
  class ContextUser

    def collect_methods
      list = @context.method_list
      unless @options.show_all
        list = list.find_all {|m| m.visibility == :public }
      end
      @methods = list.collect {|m| MyHtmlMethod.new(m, self, @options) }
    end

  end # class MyContextUser


  ##
  # Override the HtmlMethod class so we can do more intelligent code markup in markup_code()
  class MyHtmlMethod < HtmlMethod
    include MarkUp

    ##
    # Given a sequence of source tokens, mark up the source code
    # to make it look purty.
    
    def markup_code(tokens)
      src = ""
      tokens.each do |t|
			next unless t

			tokenText = t.text.gsub( /\t/ ) {|tab|
				match = $~
				
				if (match.pre_match.length % 4).nonzero?
					" " * match.pre_match.length % 4
				else
					" " * 4
				end
			}
			tokenText = CGI::escapeHTML( tokenText )

			style = case t
					when RubyToken::TkCONSTANT
						"ruby-constant"
					when RubyToken::TkKW
						"ruby-keyword"
					when RubyToken::TkIVAR
						"ruby-ivar"
					when RubyToken::TkOp
						"ruby-operator"
					when RubyToken::TkId
						"ruby-identifier"
					when RubyToken::TkNode
						"ruby-node"
					when RubyToken::TkCOMMENT
						"ruby-comment"
					when RubyToken::TkREGEXP
						"ruby-regexp"
					when RubyToken::TkVal
						"ruby-value"
					else
						nil
					end

			if style
				src << "<span class=\"#{style}\">#{tokenText}</span>"
			else
				src << tokenText
			end
		end
		src
    end

  end # class MyHtmlMethod

  class MYHTMLGenerator < HTMLGenerator ; end

end # module Generators
