#!/usr/bin/ruby
# 
# This file contains the MUES::TelnetOutputFilter class, a TELNET filter class
# for the MUES::IOEventStream. It is a specialization of
# MUES::SocketOutputFilter that understands TELNET option negotiation and some
# basic terminal features.
# 
# == Synopsis
# 
#   require 'mues/filters/telnetoutputfilter'
# 
#   tf = MUES::TelnetOutputFilter.new( socketObj )
# 
# == Rcsid
# 
# $Id: telnetoutputfilter.rb,v 1.16 2003/10/13 04:02:14 deveiant Exp $
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

require "thread"
require "hashslice"
require "sync"

require 'mues/object'
require 'mues/exceptions'
require 'mues/filters/socketoutputfilter'
require 'mues/filters/telnetconstants'

module MUES

	### A TELNET protocol error exception class
	def_exception :TelnetError, "Telnet protocol error", MUES::Exception

	### A derivative of MUES::SocketOutputFilter that understands TELNET option
	### negotiation and some basic terminal features.
	class TelnetOutputFilter < MUES::SocketOutputFilter ; implements MUES::Debuggable
		include TelnetConstants, MUES::TypeCheckFunctions

		### A module that contains constants used in TELNET option negotiation
		### (ala RFC1143 [The Q Method of Implementing Telnet Option
		### Negotiation, http://www.faqs.org/rfcs/rfc1143.html]).
		module StateConstants
			YES				= 1
			NO				= 2
			WANTYES			= 3
			WANTNO			= 4
			WANTYESQUEUED	= 5
			WANTNOQUEUED	= 6
		end
		include StateConstants

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.16 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: telnetoutputfilter.rb,v 1.16 2003/10/13 04:02:14 deveiant Exp $

		# List of supported options and whether we ask for or offer them
		Supported = {
			TELOPT_NAWS		=> 'ask',
			TELOPT_TTYPE	=> 'ask',
			TELOPT_ECHO		=> 'offer',
			TELOPT_SGA		=> 'offer',
			TELOPT_STATUS	=> 'offer',
			TELOPT_LFLOW	=> 'ask'
		}	  

		# IOEventStream sort order
		DefaultSortPosition = 15

		
		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create and return a new telnet output filter with the specified
		### <tt>socket</tt> (an IPSocket object), <tt>reactorProxy</tt>
		### (MUES::ReactorProxy object), and an optional <tt>sortOrder</tt>.
		def initialize( socket, reactorProxy, originListener=nil, order=DefaultSortPosition )
			@cmdContBuffer	= ''
			@terminalType	= "dumb"
			@stateTrace		= []

			@optState		= Hash.new( NO )
			@optStateMutex	= Sync.new

			@hideEchoFlag	= false

			@oobWriteBuffer	= ''
			@oobReadBuffer	= ''

			super( socket, reactorProxy, originListener, order )
		end


		######
		public
		######

		# The terminal-type string of the user's client
		attr_reader :terminalType

		# An array of diagnostic messages describing the steps that have been
		# taken in TELNET option negotiation.
		attr_reader :stateTrace


		### Start the filter.
		def start( stream )
			super( stream )

			self.enableTelnetOption( TELOPT_NAWS )
			self.enableTelnetOption( TELOPT_TTYPE )
			self.enableTelnetOption( TELOPT_SGA )
			self.enableTelnetOption( TELOPT_ECHO )
			# self.enableTelnetOption( TELOPT_STATUS )
			# self.enableTelnetOption( TELOPT_LFLOW )
		end

		### Get the height of the user's window (if the user's telnet client
		### supports the <tt>NAWS</tt> command). The default
		### (MUES::SocketOutputFilter::DefaultWindowSize) will be returned if
		### the user is using a client that can't report its window size.
		def windowHeight
			return @windowSize['height']
		end

		### Get the width of the user's window (if the user's telnet client
		### supports the <tt>NAWS</tt> command). The default
		### (MUES::SocketOutputFilter::DefaultWindowSize) will be returned if
		### the user is using a client that can't report its window size.
		def windowWidth
			return @windowSize['width']
		end

		### Enable the specified telnet <tt>option</tt>, if supported. The
		### <tt>option</tt> argument can be either an option name (eg.,
		### <tt>'NAWS'</tt>, <tt>'SGA'</tt>, <tt>'TSPEED'</tt>, etc.), or a raw
		### option code.
		def enableTelnetOption( option )
			optcode = nil

			# If the option is longer than one character, try to look it up in
			# the option table
			if option.length > 1
				optcode = OPTCODE[ option ] or
					raise TelnetError, "Unknown or illegal telnet option '#{option}'."

			# Otherwise, it must be a raw code, so look it up in the inverted
			# option table
			else
				optcode = option
				option = OPT[ optcode ] or
					raise TelnetError, "Unknown or illegal telnet option code '#{optcode[0]}'"
			end

			disposition = Supported[ optcode ] or
				raise TelnetError, "Unsupported telnet option '#{option}'"

			# Decide what to do based on the current state of the option in our
			# state machine
			@optStateMutex.synchronize( Sync::SH ) {
				case @optState[ option ]

				when NO

					# The disposition of the option determines whether we're asking
					# the client to do something (ask), or offering to do something
					# for the client (offer).
					case disposition
					when 'offer'
						debugMsg( 4, "Sending IAC WILL #{option}" )
						addStateTrace( "<-- I would like to enable the #{option} option." )
						sendInBand( IAC + WILL + optcode )
						@optStateMutex.synchronize( Sync::EX ) {
							@optState[ option ] = WANTYES
						}

					when 'ask'
						debugMsg( 4, "Sending IAC DO #{option}" )
						addStateTrace( "<-- Please enable the #{option} option." )
						sendInBand( IAC + DO + optcode )
						@optStateMutex.synchronize( Sync::EX ) {
							@optState[ option ] = WANTYES
						}

					else
						raise TelnetError, "Unknown disposition for option '#{option}': #{disposition}"
					end

				when YES
					debugMsg( 3, "Option '#{option}' already enabled." )

				when WANTYES
					debugMsg( 3, "Option '#{option}': Already negotiating for enable." )

				when WANTNO
					debugMsg( 3, "Option '#{option}': Already nogotiating for disable: Queueing enable request." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = WANTNOQUEUED
					}

				when WANTYESQUEUED
					debugMsg( 3, "Option '#{option}': Removing queued disable request." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = WANTYES
					}

				when WANTNOQUEUED
					debugMsg( 3, "Option '#{option}': Already have a enable request queued." )

				else
					raise TelnetError, "Illegal optState '#{@optState[option]}'"
				end
			}

			return true
		end


		### Disable the specified telnet <tt>option</tt>, if supported. The
		### <tt>option</tt> argument can be either an option name (eg.,
		### <tt>'NAWS'</tt>, <tt>'SGA'</tt>, <tt>'TSPEED'</tt>, etc.), or a raw
		### option code.
		def disableTelnetOption( option )
			optcode = nil

			# If the option is longer than one character, try to look it up in
			# the option table
			if option.length > 1
				optcode = OPTCODE[ option ] or
					raise TelnetError, "Unknown or illegal telnet option '#{option}'."

			# Otherwise, it must be a raw code, so look it up in the inverted
			# option table
			else
				optcode = option
				option = OPT[ optcode ] or
					raise TelnetError, "Unknown or illegal telnet option code '#{optcode[0]}'"
			end

			disposition = Supported[ optcode ] or
				raise TelnetError, "Unsupported telnet option '#{option}'"

			# Decide what to do based on the current state of the option in our
			# state machine
			@optStateMutex.synchronize( Sync::SH ) {
				case @optState[ option ]

				when YES

					# The disposition of the option determines whether we're asking
					# the client to do something (ask), or offering to do something
					# for the client (offer).
					case disposition
					when 'offer'
						debugMsg( 4, "Sending IAC WONT #{option}" )
						addStateTrace( "<-- I am disabling the #{option} option." )
						sendInBand( IAC + WONT + optcode )
						@optStateMutex.synchronize( Sync::EX ) {
							@optState[ option ] = WANTNO
						}

					when 'ask'
						debugMsg( 4, "Sending IAC DONT #{option}" )
						addStateTrace( "<-- Please disable the #{option} option." )
						sendInBand( IAC + DONT + optcode )
						@optStateMutex.synchronize( Sync::EX ) {
							@optState[ option ] = WANTNO
						}

					else
						raise TelnetError, "Unknown disposition for option '#{option}': #{disposition}"
					end

				when NO
					debugMsg( 3, "Option '#{option}' already disabled." )

				when WANTNO
					debugMsg( 3, "Option '#{option}': Already negotiating for disable." )

				when WANTYES
					debugMsg( 3, "Option '#{option}': Already nogotiating for enable: Queueing disable request." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = WANTYESQUEUED
					}

				when WANTNOQUEUED
					debugMsg( 3, "Option '#{option}': Removing queued enable request." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = WANTNO
					}

				when WANTYESQUEUED
					debugMsg( 3, "Option '#{option}': Already have a disable request queued." )

				else
					raise TelnetError, "Illegal optState '#{@optState[option]}'"
				end
			}

			return true
		end


		### Append a string directly onto the output buffer with a
		### line-ending. Useful when doing direct output and flush.
		def puts( aString )
			appendToWriteBuffer( aString + EOL )
		end

		### Send the specified +message+ in-band.
		def sendInBand( message )
			debugMsg( 5, "Sending in-band: " + hexdump( message ) )
			self.write( message )
		end

		### Send the specified +message+ as out-of-band urgent data <em>(currently
		### unimplemented)</em>.
		def sendOutOfBand( message )
			raise UnimplementedMethodError
		end


		### Handle the specified output <tt>events</tt> by appending their data
		### to the output buffer.
		def handleOutputEvents( *events )
			events.each {|e|
				if e.kind_of?( MUES::IOControlOutputEvent )
					handleIOControlOutputEvent( e )
				end
				
				e.data.gsub!( /\n/, EOL )
			}

			super( *events )
		end

		### Queue the specified output <tt>events</tt> for later transmission.
		def queueOutputEvents( *events )
			events.flatten!

			events.each {|e|
				if e.kind_of?( MUES::IOControlOutputEvent )
					handleIOControlOutputEvent( e )
				end
			}
					
			return super( events )
		end


		#########
		protected
		#########

		### Append the specified <tt>data</tt> to the output buffer if we're
		### handling echo for the client. If we're not, don't do anything.
		def echo( data )
			if @optState[ 'ECHO' ] == YES
				data.gsub!( /(?:\x7f)/, "\x08 \x08")
				data.gsub!( /\x0d/, EOL )

				if @hideEchoFlag
					debugMsg( 5, "Masking echo: '#{data}' (#{hexdump data})" )
					data.gsub!( /[\x20-\x7e]+/ ) {|s| "*" * s.length }
				end

				debugMsg( 5, "Sending echo: '#{data}' (#{hexdump data})" )
				sendInBand( data )
			end
		end


		### Handle the specified terminal control or special output <tt>event</tt>.
		def handleIOControlOutputEvent( event )
			checkType( event, MUES::IOControlOutputEvent )

			res = []

			case event
			when HiddenInputPromptEvent
				debugMsg( 2, "Turning masked echo on for hidden input." )
				@hideEchoFlag = true

			when PromptEvent
				debugMsg( 2, "Translating prompt to output event." )

			else
				debugMsg( 2, "Unhandled control event (#{event.class.name})." )
			end

			return res
		end


		# :TODO: This routine either needs to be broken out in several smaller
		# methods, or shortened.

		### Parse input events and telnet commands from the given raw
		### <tt>inputBuffer</tt> and return the (possibly) modified buffer.
		def handleRawInput( inputBuffer )

			debugMsg( 4, "Handling raw input: #{hexdump inputBuffer}" )

			# Prepend any partial commands from the last run
			unless @cmdContBuffer.empty?
				debugMsg( 2, "Prepending command continuation buffer (#{hexdump @cmdContBuffer})" )
				inputBuffer = @cmdContBuffer + inputBuffer
				@cmdContBuffer = ''
			end

			# Extract telnet commands
			i = 0; while i < inputBuffer.length

				unless inputBuffer[i,1] == IAC
					echo( inputBuffer[i,1] )
					i += 1
					next
				end

				debugMsg( 5, "Found an IAC..." )

				# If there's nothing after the command character, we save it for
				# the next round and break out of the loop
				if i == inputBuffer.length - 1
					debugMsg( 5, "IAC is alone at end of buffer. Saving for next round." )
					@cmdContBuffer = IAC
					inputBuffer[ i, 1 ] = ''
					break
				end

				# Now figure out which command it is
				begin
					command = inputBuffer[i+1,1]
					raise TelnetError, "Encountered unrecognized telnet command #{command[0]}" unless
						CMD.has_key?( command )

					debugMsg( 5, "...followed by '#{CMD[command]}'..." )

					case command

					# Escaped IAC
					when IAC
						debugMsg( 5, "...escaped IAC. Unescaping." )
						inputBuffer[i] = ''
						i += 1

					# Sub-option negotiation
					# IAC | SB  | NAWS 0 80 0 23 | IAC  | SE
					#  i  | i+1 | i+2   ..   i+6 | i+7  | i+8
					#    ...    |   ([^#{SE}]+)  |     ...
					when SB
						debugMsg( 5, "...Suboption negotiation. Parsing suboption..." )
						match = /([^#{SE}]+)#{IAC}#{SE}/.match( inputBuffer[i+2..-1] ) or
							raise TelnetError, "Malformed sub-option negotiation command: " +
								hexdump( inputBuffer[i+2..-1] )

						handleTelnetSuboption( match[1] )
						inputBuffer[ i, 2 + match[0].length ] = ''

					# Option negotiation
					# IAC | WILL | NAWS
					#  i  | i+1  | i+2
					when DO
						debugMsg( 5, "...DO (#{OPT[inputBuffer[i+2,1]]}). Handling." )
						handleTelnetDo( inputBuffer[i+2,1] )
						inputBuffer[i,3] = ''

					when DONT
						debugMsg( 5, "...DONT (#{OPT[inputBuffer[i+2,1]]}). Handling." )
						handleTelnetDont( inputBuffer[i+2,1] )
						inputBuffer[i,3] = ''

					when WILL
						debugMsg( 5, "...WILL (#{OPT[inputBuffer[i+2,1]]}). Handling." )
						handleTelnetWill( inputBuffer[i+2,1] )
						inputBuffer[i,3] = ''

					when WONT
						debugMsg( 5, "...WONT (#{OPT[inputBuffer[i+2,1]]}). Handling." )
						handleTelnetWont( inputBuffer[i+2,1] )
						inputBuffer[i,3] = ''


					# Other commands
					when GA
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetGoAhead();			inputBuffer[ i, 2 ] = ''
					when EL
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetEraseLine();		inputBuffer[ i, 2 ] = ''
					when EC
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetEraseChar();		inputBuffer[ i, 2 ] = ''
					when AYT
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetAreYouThere();		inputBuffer[ i, 2 ] = ''
					when AO
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetAbortOutput();		inputBuffer[ i, 2 ] = ''
					when IP
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetInterrupt();		inputBuffer[ i, 2 ] = ''
					when BREAK
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetBreak();			inputBuffer[ i, 2 ] = ''
					when DM
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetDatamark();			inputBuffer[ i, 2 ] = ''
					when NOP
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetNoop();				inputBuffer[ i, 2 ] = ''
					when EOR
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetEndOfRecord();		inputBuffer[ i, 2 ] = ''
					when ABORT
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetAbort();			inputBuffer[ i, 2 ] = ''
					when SUSP
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetSuspend();			inputBuffer[ i, 2 ] = ''
					when EOF
						debugMsg( 5, "...#{CMD[command]}. Handling." )
						handleTelnetEOF();				inputBuffer[ i, 2 ] = ''

					# Unknown command
					else
						raise TelnetError, "Unhandled telnet command '#{CMD[command]}'"

					end
					
				rescue TelnetError => e
					self.puts( "Telnet Error: #{e.message}" )
					debugMsg( 2, "Telnet Error: #{e.message}" )
				end
			end

			# Send the rest to our parent
			return super( inputBuffer )
		end


		### Parse input events from the given raw <tt>inputBuffer</tt> and
		### return the (possibly) modified buffer after queueing any input
		### events created.
		def parseInputBuffer( inputBuffer )
			newInputEvents = []

			# Look for lines ending with CR+LF in the buffer, creating an event
			# for each one.
			inputBuffer.gsub!( /^([^#{CR}#{LF}]*)#{CR}(#{LF}|#{NULL})/ ) {|s|
				input = $1

				# Do delete/backspace replacement
				while input =~ /\x7f|\x08/
					if input =~ /[^\x08\x7f](?:\x08|\x7f)/
						input.gsub!( /[^\x08\x7f](?:\x08|\x7f)/, "" )
					else
						input.gsub!( /\x7f|\x08/, "" )
					end
				end

				debugMsg( 4, "Creating an input event for input = '#{input.strip}'" )
				newInputEvents.push( InputEvent.new("#{input.strip}") )

				if @hideEchoFlag
					debugMsg( 2, "Turning echo mask off." )
					@hideEchoFlag = false
				end

				""
			}

			queueInputEvents( *newInputEvents )
			return inputBuffer
		end


		### Add a state message to the state trace array for debugging.
		def addStateTrace( msg )
			debugMsg( 2, msg )
			@stateTrace << msg
		end


		### Send a shutdown message to the client using unbuffered I/O on the
		### filter's socket.
		def sendShutdownMessage
			@socket.syswrite( @writeBuffer )
			@socket.syswrite( EOL + ">>> Disconnecting <<<" + EOL * 2 )
		end


		#############################################################
		###	T E L N E T   C O M M A N D   H A N D L E R S
		#############################################################

		### Handle suboption negotiation
		def handleTelnetSuboption( suboption )
			option = OPT[ suboption[0,1] ] or
				raise TelnetError, "Unrecognized telnet option in suboption negotiation (#{suboption[0]})"
			data = suboption[1 .. -1]

			debugMsg( 3, "Received 'SUBOPTION #{option}'." )

			case option

			# Set terminal type
			when "TTYPE"
				data, qual = [ data[0,1], data[1 .. -1] ]

				# If they're setting the terminal, everything's cool
				if qual == TELQUAL_IS
					addStateTrace( "--> My terminal type is '#{data}'" )
					@terminalType = data
					debugMsg( 3, "Set terminal type to '#{data}'" )

				# Anything else doesn't make sense for a server, so it's an error
				else
					debugMsg( 2, "Client is asking for OUR terminal type?" )
					raise TelnetError, "Client sent invalid TTYPE TELQUAL code '#{TELQUAL[qual]}'"
				end

			# Window size negotiation
			when "NAWS"
				debugMsg( 5, "Extracting height and width from NAWS data: " + hexdump(data) )
				width, height = data.unpack( 'n*' )
				addStateTrace( "--> My window size is #{width} x #{height}" )
				debugMsg( 3, "Got window size of #{width} x #{height}." )

				# Set the window size unless its some ridiculous value
				@windowSize['width'] = width if width >= 15 && width < 1024
				@windowSize['height'] = height if height >= 3 && height < 1024

			else
				addStateTrace( "--> Unhandled suboption #{option}" )
				debugMsg( 2, "Unhandled suboption #{option}" )

			end

			return true
		end


		### Option negotiation

		### Handle a 'DO' command for the specified option code (<tt>opt</tt>)
		### coming from the client.
		def handleTelnetDo( opt )
			option = OPT[ opt ] or
				raise TelnetError, "Unrecognized telnet option code (#{opt[0]})"
			
			debugMsg( 3, "Got 'DO #{option}'." )

			@optStateMutex.synchronize( Sync::SH ) {
				case @optState[ option ]

				# If the option is currently disabled, either enable it and tell the
				# client we WILL if we support it, or tell the client we WONT.
				when NO
					addStateTrace( "--> Please enable the #{option} option." )
					if Supported[ option ]
						debugMsg( 3, "Enabling and sending IAC WILL #{option}" )
						@optStateMutex.synchronize( Sync::EX ) {
							@optState[ option ] = YES
						}
						addStateTrace( "<-- Okay, I'm enabling #{option}." )
						sendInBand( IAC + WILL + opt )

					else
						debugMsg( 3, "Replying with IAC WONT to unsupported #{option} option" )
						addStateTrace( "<-- Sorry, I don't support the #{option} option." )
						sendInBand( IAC + WONT + opt )
					end

				# If the option's already enabled, don't do anything
				when YES
					debugMsg( 3, "Option is already enabled, ignoring 'DO #{option}'" )
					addStateTrace( "--> DO '#{option}' option." )
					addStateTrace( "XXX Hmmm... the #{option} option's already enabled. I'll just ignore that." )

				# If the state is WANTNO, then the client just replied with a 'DO'
				# to a 'WONT', which means they're a bozon, so we error.
				when WANTNO
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}
					addStateTrace( "--> DO '#{option}' option." )
					addStateTrace( "XXX Errr... no, I said I WONT do #{option}. Stupid bozon." )
					raise TelnetError, "Bozonic client: 'WONT #{option}' answered with 'DO #{option}'"

				# If we've offered to turn on the option, and the client has told us
				# to do so, enable the option and call the setup method if it
				# exists.
				when WANTYES
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = YES
					}
					addStateTrace( "--> Okay, enable the #{option} option." )
					debugMsg( 3, "Option '#{option}' accepted and enabled." )

					### Call the special setup method, if it exists
					if self.respond_to?( "clientDoes#{option.capitalize}".intern )
						self.send( "clientDoes#{option.capitalize}".intern )
					end

				# If the state is WANTNOQUEUED, the client just replied with a
				# 'DO' to a 'WONT', which again means that they're a
				# bozon. However, the QUEUED part of the state means that we've
				# been asked to enable the option in question since sending the
				# 'WONT', so we make the best out of the bozon's fscked reply
				# and just enable.
				when WANTNOQUEUED
					@optState[ option ] = YES
					addStateTrace( "--> DO '#{option}' option." )
					addStateTrace( "XXX Errr... I guess it's a good thing I changed my mind about " +
								    "the #{option} option. Stupid bozon." )
					debugMsg( 2, "Bozonic client: 'WONT #{option}' answered with 'DO #{option}', " +
							 "queued opposite assumed to be enabled by DO." )

					### If we have a special setup method that needs to be called
					### when the client says they'll do this option, call it. This
					### method is of the form 'clientDoes<capitalized option
					### name>'. Eg., for the 'ECHO' option, the method would be
					### 'clientDoesEcho'.
					if self.respond_to?( "clientDoes#{option.capitalize}".intern )
						self.send( "clientDoes#{option.capitalize}".intern )
					end

				# If the state is WANTYESQUEUED, then sometime between saying we
				# support the option and now, we've changed our minds and disabled
				# it again, so queue up the WONT to let the client know.
				when WANTYESQUEUED
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = WANTNO
					}
					addStateTrace( "--> Okay, enable the #{option} option." )
					debugMsg( 3, "Option '#{option}' accepted but new request for disable is queued. " +
							 "Sending 'IAC WONT #{option}'" )
					addStateTrace( "<-- Actually, I've changed my mind. I won't enable the #{option} option." )
					sendInBand( IAC + WONT + opt )

				else
					throw TelnetError, "Illegal optstate '#{@optState[option]}'"
				end
			}

			return true
		end


		### Handle a 'DONT' command for the specified option code (<tt>opt</tt>)
		### coming from the client.
		def handleTelnetDont( opt )
			option = OPT[ opt ] or
				raise TelnetError, "Unrecognized telnet option code (#{opt[0]})"
			
			debugMsg( 3, "Got 'DONT #{option}'." )

			@optStateMutex.synchronize( Sync::SH ) {
				case @optState[ option ]

				# If the option is already disabled, don't do anything
				when NO
					debugMsg( 3, "Option is already disabled. Ignoring 'DONT #{option}'" )
					addStateTrace( "--> Disable the '#{option}' option." )
					addStateTrace( "XXX Hmmm... the #{option} option's already disabled. I'll just ignore that." )

				# If the option's currently enabled, disable it and confirm
				when YES
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}
					debugMsg( 3, "Disabling #{option} option, sending WONT #{option}" )
					addStateTrace( "<-- Okay, disabling the #{option} option." )
					sendInBand( IAC + WONT + opt )

				# If the state is WANTNO, then the client has accepted our WONT
				when WANTNO
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}
					addStateTrace( "--> Okay, disable the #{option} option." )

				# If we've offered to turn on the option, and the client has told us
				# DONT, keep it disabled.
				when WANTYES
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}
					addStateTrace( "--> No thanks. Don't turn on the '#{option}' option." )
					debugMsg( 3, "'#{option}' option rejected and disabled." )

				# We've offered to turn the option off, but have since changed
				# our mind. Send a new enable request.
				when WANTNOQUEUED
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = WANTYES
					}
					addStateTrace( "--> Okay, don't enable the '#{option}' option, then." )

					debugMsg( 2, "'WONT #{option}' accepted, but new request for enable is queued Sending." +
							 "IAC WILL #{option}" )
					addStateTrace( "--> Actually, I've changed my mind about the '#{option}' option. I can " +
								    "now enable it if you want." )
					sendInBand( IAC + WILL + opt )

				# We offered to do the option, then changed our mind. Client
				# refused, which is what we want now anyway, so just disable the
				# option.
				when WANTYESQUEUED
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}
					addStateTrace( "--> Please don't enable the '#{option}' option." )
					addStateTrace( "XXX Okay, I won't. I'd changed my mind about enabling it anyway." )
					debugMsg( 3, "Option '#{option}' rejected, matching queued disable request. " +
							  "Disabling #{option} option." )

				else
					throw TelnetError, "Illegal optstate '#{@optState[option]}'"
				end
			}

			return true
		end


		### Handle a 'WILL' command for the specified option code (<tt>opt</tt>)
		### coming from the client.
		def handleTelnetWill( opt )
			option = OPT[ opt ] or
				raise TelnetError, "Unrecognized telnet option code (#{opt[0]})"
			
			debugMsg( 3, "Got 'WILL #{option}'." )

			@optStateMutex.synchronize( Sync::SH ) {
				case @optState[ option ]

				# If the option is currently disabled, either enable it and tell the
				# client we WILL if we support it, or tell the client we WONT.
				when NO
					addStateTrace( "--> Hey, I can enable the '#{option}' option, if you want." )
					if Supported[ option ]
						debugMsg( 3, "Enabling and sending IAC DO #{option}" )
						@optStateMutex.synchronize( Sync::EX ) {
							@optState[ option ] = YES
						}
						addStateTrace( "<-- Hey, yeah. Please enable '#{option}'." )
						sendInBand( IAC + DO + opt )

					else
						debugMsg( 3, "Replying with IAC DONT to unsupported #{option} option" )
						addStateTrace( "<-- Naw, that's okay. I don't need '#{option}'. Keep it disabled." )
						sendInBand( IAC + DONT + opt )
					end

				# If the option's already enabled, don't do anything
				when YES
					addStateTrace( "--> Hey, I can enable the '#{option}' option, if you want." )
					addStateTrace( "XXX Errr... that's nice. We already had it enabled." )
					debugMsg( 3, "Option is already enabled, ignoring 'WILL #{option}'" )

				# If the state is WANTNO, then the client just replied with a 'WILL'
				# to a 'DONT', which means they're a bozon, so we error.
				when WANTNO
					addStateTrace( "--> Okay, I'll enable the '#{option}' option." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}
					addStateTrace( "XXX WTF? I said DONT do #{option}. Fscking bozon." )
					raise TelnetError, "Bozonic client: 'DONT #{option}' answered with 'WILL #{option}'"

				# If we've offered to turn on the option, and the client has told us
				# to do so, enable the option and call the setup method if it
				# exists.
				when WANTYES
					addStateTrace( "--> Excellent! Enable the #{option} option then." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = YES
					}
					debugMsg( 3, "Option '#{option}' accepted and enabled." )

					### Call the special setup method, if it exists
					if self.respond_to?( "clientWill#{option.capitalize}".intern )
						self.send( "clientWill#{option.capitalize}".intern )
					end

				# If the state is WANTNOQUEUED, the client just replied with a
				# 'WILL' to a 'DONT', which again means that they're a
				# bozon. However, the QUEUED part of the state means that we've
				# been asked to enable the option in question since sending the
				# 'DONT', so we make the best out of the bozon's fscked reply
				# and just enable.
				when WANTNOQUEUED
					addStateTrace( "--> Okay, I'll enable the '#{option}' option." )
					@optState[ option ] = YES
					addStateTrace( "XXX Errr... despite telling you not to? Well, good thing I "+
								    "changed my mind, then." )
					debugMsg( 2, "Bozonic client: 'DONT #{option}' answered with 'WILL #{option}', " +
							 "queued opposite assumed to be enabled by WILL." )

					### If we have a special setup method that needs to be called
					### when the client says they'll do this option, call it. This
					### method is of the form 'clientDoes<capitalized option
					### name>'. Eg., for the 'ECHO' option, the method would be
					### 'clientDoesEcho'.
					if self.respond_to?( "clientWill#{option.capitalize}".intern )
						self.send( "clientWill#{option.capitalize}".intern )
					end

				# If the state is WANTYESQUEUED, then sometime between asking
				# for the option and now, we've changed our minds and disabled
				# it again, so queue up the DONT to let the client know.
				when WANTYESQUEUED
					addStateTrace( "--> Okay, I'll enable the '#{option}' option." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = WANTNO
					}
					debugMsg( 3, "Option '#{option}' accepted but new request for disable is queued. " +
							 "Sending 'IAC DONT #{option}'" )
					addStateTrace( "<-- Actually, I've changed my mind. Don't enable the #{option} option." )
					sendInBand( IAC + DONT + opt )

				else
					throw TelnetError, "Illegal optstate '#{@optState[option]}'"
				end
			}

			return true
		end


		### Handle a 'WONT' command for the specified option code (<tt>opt</tt>)
		### coming from the client.
		def handleTelnetWont( opt )
			option = OPT[ opt ] or
				raise TelnetError, "Unrecognized telnet option code (#{opt[0]})"
			
			debugMsg( 3, "Got 'WONT #{option}'." )

			@optStateMutex.synchronize( Sync::SH ) {
				case @optState[ option ]

				# If the option is already disabled, don't do anything
				when NO
					addStateTrace( "--> I don't support the '#{option}' option." )
					addStateTrace( "XXX Errr... okay. I wasn't asking for it anyway." )
					debugMsg( 3, "Option is already disable. Ignoring 'WONT #{option}'" )

				# If the option's current enabled, disable it and confirm
				when YES
					addStateTrace( "--> I want to turn off the '#{option}' option." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}
					debugMsg( 3, "Disabling #{option} option, sending DONT #{option}" )
					addStateTrace( "<-- Okay. Turn off #{option}." )
					sendInBand( IAC + DONT + opt )

				# If the state is WANTNO, then the client has accepted our DONT
				when WANTNO
					addStateTrace( "--> Okay, I'll disable the '#{option}' option." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}

				# If we've asked the client to turn on the option, and the
				# client has told us WONT, keep it disabled.
				when WANTYES
					addStateTrace( "--> Sorry, I don't support the '#{option}' option." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}
					debugMsg( 3, "'#{option}' option rejected and disabled." )

				# We've asked the client to turn the option off, but have since
				# changed our mind. Send a new enable request.
				when WANTNOQUEUED
					addStateTrace( "--> Okay, I'll disable the '#{option}' option." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = WANTYES
					}
					debugMsg( 2, "'DONT #{option}' accepted, but new request for enable is queued. Sending." +
							 "IAC DO #{option}" )
					addStateTrace( "--> Actually, I've changed my mind about the '#{option}' option. Please " +
								    "enable it again." )
					sendInBand( IAC + DO + opt )

				# We asked for the option, then changed our mind. Client
				# refused, which is what we want now anyway, so just disable the
				# option.
				when WANTYESQUEUED
					addStateTrace( "--> Sorry, I don't support the '#{option}' option." )
					@optStateMutex.synchronize( Sync::EX ) {
						@optState[ option ] = NO
					}
					debugMsg( 3, "'DO #{option}' rejected, matching queued disable request. " +
							  "Disabling #{option} option." )
					addStateTrace( "XXX That's okay. I'd changed my mind about wanting it anyway." )

				else
					throw TelnetError, "Illegal optstate '#{@optState[option]}'"
				end
			}

			return true
		end


		### Other telnet commands

		### Handle a 'go ahead' command sent by the client.
		def handleTelnetGoAhead()
			debugLog( 5, "Received telnet 'go ahead'." )
			addStateTrace( "--> You may reverse the line." )
			return false
		end

		### Handle a 'erase current line' command sent by the client.
		def handleTelnetEraseLine()
			debugLog( 5, "Received telnet 'erase line'." )
			addStateTrace( "--> Erase the current line." )
			return false
		end

		### Handle a 'erase current character' command sent by the client.
		def handleTelnetEraseChar()
			debugLog( 5, "Received telnet 'erase char'." )
			addStateTrace( "--> Erase the current character." )
			return false
		end

		### Handle a 'are you there' command sent by the client.
		def handleTelnetAreYouThere()
			debugLog( 5, "Received telnet 'are you there'." )
			addStateTrace( "--> Are you there?" )
			queueOutputEvents( OutputEvent.new("MUES Server: [yes]") )
			return true
		end

		### Handle a 'abort output' command sent by the client.
		def handleTelnetAbortOutput()
			debugLog( 5, "Received telnet 'abort output'." )
			addStateTrace( "--> Abort output from the current process." )
			return false
		end

		### Handle an 'interrupt' command sent by the client.
		def handleTelnetInterrupt()
			debugLog( 5, "Received telnet 'interrupt'." )
			addStateTrace( "--> Interrupt the current process permanently." )
			return false
		end

		### Handle a 'break' command sent by the client.
		def handleTelnetBreak()
			debugLog( 5, "Received telnet 'break'." )
			addStateTrace( "--> BREAK." )
			return false
		end

		### Handle a telnet datamark.
		def handleTelnetDatamark()
			debugLog( 5, "Received telnet datamark." )
			addStateTrace( "--> [MARK]" )
			return false
		end

		### Handle a 'no-op' command sent by the client.
		def handleTelnetNoop()
			debugLog( 5, "Received telnet 'NOP'." )
			addStateTrace( "--> (No-op)" )
			return false
		end

		### Handle a 'end of record' command sent by the client.
		def handleTelnetEndOfRecord()
			debugLog( 5, "Received telnet 'end of record'." )
			addStateTrace( "--> End of record." )
			return false
		end

		### Handle an 'abort' command sent by the client.
		def handleTelnetAbort()
			debugLog( 5, "Received telnet abort." )
			addStateTrace( "--> Abort the current process." )
			return false
		end

		### Handle a 'suspend' command sent by the client.
		def handleTelnetSuspend()
			debugLog( 5, "Received telnet 'suspend'." )
			addStateTrace( "--> Suspend current process." )
			return false
		end

		### Handle an 'end of file' command sent by the client.
		def handleTelnetEOF()
			debugLog( 5, "Received telnet EOF." )
			addStateTrace( "--> End of file." )
			return false
		end


		### Suboption response handlers

		### Handle the client telling us they'll do TTYPE: ask for their
		### terminal type.
		def handleWillTtype()
			debugMsg( 4, "Handling a WILL TTYPE from the client: Sending 'IAC SB TTYPE SEND IAC SE'" )
			addStateTrace( "<-- Okay, send me your terminal type." )
			sendInBand( IAC + SB + TELOPT_TTYPE + TELQUAL_SEND + IAC + SE )
			return true
		end

		### Handle the client telling us to take over their echo.
		def handleDoEcho()
			debugMsg( 4, "We are now handling echo for the client." )
			addStateTrace( "<-- Okay, now I'm handling your echo for you." )
		end



		#######
		private
		#######

		### Turn a string of <tt>data</tt> into its hex equivalent
		def hexdump( data )
			data.to_s.split(//).collect {|b| sprintf "%02x", b[0] }.join(' ')
		end


	end # class TelnetOutputFilter
end # module MUES

