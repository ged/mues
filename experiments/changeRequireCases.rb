#!/usr/bin/ruby
# 
# Script to rewrite requires in MUES files to reflect change in file-naming
# convention to all-lowercase.
# 
# == Subversion ID
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Copyright (c) 2001-2004, The FaerieMUD Consortium.
#
# This is free software. You may use, modify, and/or redistribute this software
# under the terms of the Perl Artistic License. (See
# http://language.perl.com/misc/Artistic.html)
#

require "./utils.rb"
include UtilityFunctions

header "MUES require-rewrite script"

%w{lib server experiments tests}.each {|dir|
	message "Searching #{dir}...\n"

	Dir["#{dir}/**/*"].each do |file|
		next if !File::file?( file ) ||
			/CVS/ =~ file
		message "Editing #{file}...\n"

		editInPlace( file ) {|line|
			line.gsub( /require (["'])mues\/([^'"]+)\1/ ) {
				%q{require 'mues/%s'} % Regexp::last_match.captures[1].downcase
			}
		}

		divider( 75 )
	end
}


