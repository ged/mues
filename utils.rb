#
#	MUES Documentation Generation Script
#	$Id: utils.rb,v 1.1 2001/11/01 15:52:08 deveiant Exp $
#
#	Copyright (c) 2001, The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

require "readline"
include Readline

module UtilityFunctions

	# Set some ANSI escape code constants (Shamelessly stolen from Perl's
	# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
	AnsiAttributes = {
		'clear'      => 0,
		'reset'      => 0,
		'bold'       => 1,
		'dark'       => 2,
		'underline'  => 4,
		'underscore' => 4,
		'blink'      => 5,
		'reverse'    => 7,
		'concealed'  => 8,

		'black'      => 30,   'on_black'   => 40, 
		'red'        => 31,   'on_red'     => 41, 
		'green'      => 32,   'on_green'   => 42, 
		'yellow'     => 33,   'on_yellow'  => 43, 
		'blue'       => 34,   'on_blue'    => 44, 
		'magenta'    => 35,   'on_magenta' => 45, 
		'cyan'       => 36,   'on_cyan'    => 46, 
		'white'      => 37,   'on_white'   => 47
	}
	def ansiCode( *attributes )
		attr = attributes.collect {|a| AnsiAttributes[a] ? AnsiAttributes[a] : nil}.compact.join(';')
		if attr.empty? 
			return ''
		else
			return "\e[%sm" % attr
		end
	end
	ErasePreviousLine = "\033[A\033[K"

	def testForLibrary( lib, nicename=nil )
		nicename ||= "'lib'"
		message( "Testing for the #{nicename} library..." )
		if $:.detect {|dir| File.exists?(File.join(dir,"#{lib}.rb")) || File.exists?(File.join(dir,"#{lib}.so"))}
			message( "found.\n" )
			return true
		else
			message( "not found.\n" )
			return false
		end
	end

	def testForRequiredLibrary( lib, nicename=nil, raaUrl=nil, downloadUrl=nil )
		nicename ||= "'lib'"
		unless testForLibrary( lib, nicename )
			msgs = [ "You must install the #{nicename} library to run MUES.\n" ]
			msgs << "RAA: #{raaUrl}\n" if raaUrl
			msgs << "Download: #{downloadUrl}\n" if downloadUrl
			message( msgs )
			exit 1
		end
		return true
	end

	def header( msg )
		msg.chomp!
		print ansiCode( 'bold', 'white' ) + msg + ansiCode( 'reset' ) + "\n"
	end

	def message( msg )
		print msg
	end

	def replaceMessage( *msg )
		print ErasePreviousLine
		message( *msg )
	end

	def abort( msg )
		print ansiCode( 'bold', 'red' ) + "Aborted: " + msg.chomp + ansiCode( 'reset' ) + "\n\n"
		Kernel.exit!( 1 )
	end

	def prompt( promptString )
		promptString.chomp!
		return readline( "#{promptString}: " ).strip
	end

	def promptWithDefault( promptString, default )
		response = prompt( promptString )
		if response.empty?
			return default
		else
			return response
		end
	end

	def findProgram( progname )
		ENV['PATH'].split(File::PATH_SEPARATOR).each {|d|
			file = File.join( d, progname )
			return file if File.executable?( file )
		}
		return nil
	end
end
