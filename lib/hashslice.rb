#!/usr/bin/ruby
# 
# =hashslice.rb
# 
# == Name
# 
# hashslice - Slicing for Ruby Hashes
# 
# == Synopsis
# 
#   require "hashslice"
# 
#   hash = {
#     "this" => "is",
#     "a" => "test",
#     "hash" => "for",
#     "the" => "synopsis"
#   }
#
#   hash[ "this", "hash" ]
#   #  ==>["is", "for"]
# 
#   hash[ "a", "hash" ] = "something", "else"
#   #  ==>["a", "hash"]
#
#	hash
# 
# == Description
# 
# This module adds slicing to Ruby hashes, similar to Perl^s hash slices. If the
# argument to (({Hash#[]})) is an (({Array})) object with one or more keys, the
# return value will be an array of the corresponding values.
# 
# == Author
# 
# Michael Granger <ged@FaerieMUD.org>
# 
# Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.
# 
# This module is free software. You may use, modify, and/or redistribute this
# software under the terms of the Perl Artistic License. (See
# http://language.perl.com/misc/Artistic.html)
# 

##
# Add slicing to the builtin Hash class.
class Hash

	##
	# Alias the regular methods out of the way so we can override 'em.
	alias :__bracketBracket__ :[]
	alias :__bracketBracketEq__ :[]=

	##
	# Add slicing to element reference operator
	def []( *sliceKeys )
		if sliceKeys.length == 1
			return __bracketBracket__( sliceKeys[0] )
		end
		return sliceKeys.collect {|k| __bracketBracket__( k )}
	end

	##
	# Add slicing to element assignment operator.
	def []=( *args )
		if args.length <= 2
			return __bracketBracketEq__( *args )
		end
		aVals = args.pop
		aVals = [aVals] unless aVals.kind_of?( Array )
		args.each_index {|i| __bracketBracketEq__( args[i], aVals[i] )}
	end

end


