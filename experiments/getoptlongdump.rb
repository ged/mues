#!/usr/bin/ruby -w

#
#	Test code to dump options as parsed by the getoptlong module 
#


require 'pp'
require 'getoptlong'


opts = GetoptLong.new
opts.set_options(
	[ '--verbose',	'-v',	GetoptLong::NO_ARGUMENT ],
	[ '--debug',	'-d',	GetoptLong::NO_ARGUMENT ],
	[ '--output',	'-o',	GetoptLong::REQUIRED_ARGUMENT ]
)


opts.each {|name,arg|
	print "Name: "
	pp name
	print "Arg: "
	pp arg
}
