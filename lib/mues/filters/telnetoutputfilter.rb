#!/usr/bin/ruby
###########################################################################
=begin

=TelnetOutputFilter.rb

== Name

TelnetOutputFilter - A telnet IOEvent filter class

== Synopsis

  

== Description



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "thread"

require "mues/Namespace"
require "mues/Exceptions"

module MUES
	module TelnetConstants
		CMD = {
    		'IAC'   => 255.chr,		# "\377" # "\xff" # interpret as command:
    		'DONT'  => 254.chr,		# "\376" # "\xfe" # you are not to use option
    		'DO'    => 253.chr,		# "\375" # "\xfd" # please, you use option
    		'WONT'  => 252.chr,		# "\374" # "\xfc" # I won't use option
    		'WILL'  => 251.chr,		# "\373" # "\xfb" # I will use option
    		'SB'    => 250.chr,		# "\372" # "\xfa" # interpret as subnegotiation
    		'GA'    => 249.chr,		# "\371" # "\xf9" # you may reverse the line
    		'EL'    => 248.chr,		# "\370" # "\xf8" # erase the current line
    		'EC'    => 247.chr,		# "\367" # "\xf7" # erase the current character
    		'AYT'   => 246.chr,		# "\366" # "\xf6" # are you there
    		'AO'    => 245.chr,		# "\365" # "\xf5" # abort output--but let prog finish
    		'IP'    => 244.chr,		# "\364" # "\xf4" # interrupt process--permanently
    		'BREAK' => 243.chr,		# "\363" # "\xf3" # break
    		'DM'    => 242.chr,		# "\362" # "\xf2" # data mark--for connect. cleaning
    		'NOP'   => 241.chr,		# "\361" # "\xf1" # nop
    		'SE'    => 240.chr,		# "\360" # "\xf0" # end sub negotiation
    		'EOR'   => 239.chr,		# "\357" # "\xef" # end of record (transparent mode)
    		'ABORT' => 238.chr,		# "\356" # "\xee" # Abort process
    		'SUSP'  => 237.chr,		# "\355" # "\xed" # Suspend process
    		'EOF'   => 236.chr,		# "\354" # "\xec" # End of file
    		'SYNCH' => 242.chr		# "\362" # "\xf2" # for telfunc calls
		}
		CMDCODE = CMD.reverse

		OPT = {
    		'BINARY'         => 0.chr,		# "\000" # "\x00" # Binary Transmission
    		'ECHO'           => 1.chr,		# "\001" # "\x01" # Echo
    		'RCP'            => 2.chr,		# "\002" # "\x02" # Reconnection
    		'SGA'            => 3.chr,		# "\003" # "\x03" # Suppress Go Ahead
    		'NAMS'           => 4.chr,		# "\004" # "\x04" # Approx Message Size Negotiation
    		'STATUS'         => 5.chr,		# "\005" # "\x05" # Status
    		'TM'             => 6.chr,		# "\006" # "\x06" # Timing Mark
    		'RCTE'           => 7.chr,		# "\a"   # "\x07" # Remote Controlled Trans and Echo
    		'NAOL'           => 8.chr,		# "\010" # "\x08" # Output Line Width
    		'NAOP'           => 9.chr,		# "\t"   # "\x09" # Output Page Size
    		'NAOCRD'         => 10.chr,		# "\n"   # "\x0a" # Output Carriage-Return Disposition
    		'NAOHTS'         => 11.chr,		# "\v"   # "\x0b" # Output Horizontal Tab Stops
    		'NAOHTD'         => 12.chr,		# "\f"   # "\x0c" # Output Horizontal Tab Disposition
    		'NAOFFD'         => 13.chr,		# "\r"   # "\x0d" # Output Formfeed Disposition
    		'NAOVTS'         => 14.chr,		# "\016" # "\x0e" # Output Vertical Tabstops
    		'NAOVTD'         => 15.chr,		# "\017" # "\x0f" # Output Vertical Tab Disposition
    		'NAOLFD'         => 16.chr,		# "\020" # "\x10" # Output Linefeed Disposition
    		'XASCII'         => 17.chr,		# "\021" # "\x11" # Extended ASCII
    		'LOGOUT'         => 18.chr,		# "\022" # "\x12" # Logout
    		'BM'             => 19.chr,		# "\023" # "\x13" # Byte Macro
    		'DET'            => 20.chr,		# "\024" # "\x14" # Data Entry Terminal
    		'SUPDUP'         => 21.chr,		# "\025" # "\x15" # SUPDUP
    		'SUPDUPOUTPUT'   => 22.chr,		# "\026" # "\x16" # SUPDUP Output
    		'SNDLOC'         => 23.chr,		# "\027" # "\x17" # Send Location
    		'TTYPE'          => 24.chr,		# "\030" # "\x18" # Terminal Type
    		'EOR'            => 25.chr,		# "\031" # "\x19" # End of Record
    		'TUID'           => 26.chr,		# "\032" # "\x1a" # TACACS User Identification
    		'OUTMRK'         => 27.chr,		# "\e"   # "\x1b" # Output Marking
    		'TTYLOC'         => 28.chr,		# "\034" # "\x1c" # Terminal Location Number
    		'3270REGIME'     => 29.chr,		# "\035" # "\x1d" # Telnet 3270 Regime
    		'X3PAD'          => 30.chr,		# "\036" # "\x1e" # X.3 PAD
    		'NAWS'           => 31.chr,		# "\037" # "\x1f" # Negotiate About Window Size
    		'TSPEED'         => 32.chr,		# " "    # "\x20" # Terminal Speed
    		'LFLOW'          => 33.chr,		# "!"    # "\x21" # Remote Flow Control
    		'LINEMODE'       => 34.chr,		# "\""   # "\x22" # Linemode
    		'XDISPLOC'       => 35.chr,		# "#"    # "\x23" # X Display Location
    		'OLD_ENVIRON'    => 36.chr,		# "$"    # "\x24" # Environment Option
    		'AUTHENTICATION' => 37.chr,		# "%"    # "\x25" # Authentication Option
    		'ENCRYPT'        => 38.chr,		# "&"    # "\x26" # Encryption Option
    		'NEW_ENVIRON'    => 39.chr,		# "'"    # "\x27" # New Environment Option
    		'EXOPL'          => 255.chr		# "\377" # "\xff" # Extended-Options-List
		}
		OPTCODE = OPT.reverse

		NULL = "\000"
		CR   = "\015"
		LF   = "\012"
		EOL  = CR + LF
	end

	class TelnetOutputFilter < SocketOutputFilter ; implements Debuggable
		include TelnetConstants

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: telnetoutputfilter.rb,v 1.3 2001/07/18 02:24:11 deveiant Exp $

		### (PROTECTED) METHOD: initialize( aSocket )
		### Initialize the output filter
		protected
		def initialize( aSocket )
			super( aSocket )
		end

		#######################################################################
		###	P U B L I C   M E T H O D S
		#######################################################################
		public



	end # class TelnetOutputFilter
end # module MUES

