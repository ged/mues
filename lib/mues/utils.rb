#!/usr/bin/ruby

require 'readline'
require 'pathname'
require 'logger'
require 'erb'

require 'mues'

# 
# This file contains mixins that are used to extend other classes.
# 
# == VCS ID
#
#  $Id$
# 
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
#
# :include: LICENSE
# 
#---
#
# Please see the file LICENSE in the base directory for licensing details.
#
module MUES

	### A collection of functions for making comparable version vectors.
	module VersionFunctions

		###############
		module_function
		###############

		### Make a vector out of the given +version_string+, which makes it easier to compare 
		### with other x.y.z-style version strings.
		def vvec( version_string )
			return version_string.split('.').collect {|v| v.to_i }.pack( 'N*' )
		end

	end # module VersionFunctions


	### A collection of methods to add to Numeric for convenience (stolen from
	### ActiveSupport), split into MUES::NumericConstantMethods::Time and
	### MUES::NumericConstantMethods::Bytes.
	###
	### This module is added to Numeric in lib/mues.rb
	module NumericConstantMethods

		### Append features to the including +mod+.
		def self::append_features( mod )
			constants.each do |c|
				self.const_get( c ).send( :append_features, mod )
			end
			super
		end


		### A collection of convenience methods for calculating times using
		### Numeric objects:
		###
		###   # Add convenience methods to Numeric objects
		###   class Numeric
		###       include MUES::NumericConstantMethods::Time
		###   end
		###
		###   irb> 138.seconds.ago
		###       ==> Fri Aug 08 08:41:40 -0700 2008
		###   irb> 18.years.ago
		###       ==> Wed Aug 08 20:45:08 -0700 1990
		###   irb> 2.hours.before( 6.minutes.ago )
		###       ==> Fri Aug 08 06:40:38 -0700 2008
		###
		module Time

			### Number of seconds (returns receiver unmodified)
			def seconds
				return self
			end
			alias_method :second, :seconds

			### Returns number of seconds in <receiver> minutes
			def minutes
				return self * 60
			end
			alias_method :minute, :minutes

			### Returns the number of seconds in <receiver> hours
			def hours
				return self * 60.minutes
			end
			alias_method :hour, :hours

			### Returns the number of seconds in <receiver> days
			def days
				return self * 24.hours
			end
			alias_method :day, :days

			### Return the number of seconds in <receiver> weeks
			def weeks
				return self * 7.days
			end
			alias_method :week, :weeks

			### Returns the number of seconds in <receiver> fortnights
			def fortnights
				return self * 2.weeks
			end
			alias_method :fortnight, :fortnights

			### Returns the number of seconds in <receiver> months (approximate)
			def months
				return self * 30.days
			end
			alias_method :month, :months

			### Returns the number of seconds in <receiver> years (approximate)
			def years
				return (self * 365.25.days).to_i
			end
			alias_method :year, :years


			### Returns the Time <receiver> number of seconds before the
			### specified +time+. E.g., 2.hours.before( header.expiration )
			def before( time )
				return time - self
			end


			### Returns the Time <receiver> number of seconds ago. (e.g.,
			### expiration > 2.hours.ago )
			def ago
				return self.before( ::Time.now )
			end


			### Returns the Time <receiver> number of seconds after the given +time+.
			### E.g., 10.minutes.after( header.expiration )
			def after( time )
				return time + self
			end

			# Reads best without arguments:  10.minutes.from_now
			def from_now
				return self.after( ::Time.now )
			end

			### Return a string describing the amount of time in the given number of
			### seconds in terms a human can understand easily.
			def age_string
				return
					if self < 1.minute			then 'less than a minute'
					elsif self < 50.minutes
						"%d minute%s" % [
							(self / 1.minute).to_i,
							(self == 1.minute ? '' : 's')
						  ]
					elsif self < 120.minutes	then 'about an hour'
					elsif self < 18.hours 		then "%d hours" % (self / 1.hour).to_i
					elsif self < 1.day	 		then 'one day'
					elsif self < 2.days	 		then 'about one day'
					elsif self < 1.week  		then "%d days" % (self / 1.day).to_i
					elsif self < 2.weeks 		then 'about one week'
					elsif self < 3.months 		then "%d weeks" % (self / 1.week).to_i
					elsif self < 1.year 		then "%d months" % (self / 1.month).to_i
					else
						"%d years" % (self / 1.year).to_i
					end
			end

		end # module Time


		### A collection of convenience methods for calculating bytes using
		### Numeric objects:
		###
		###   # Add convenience methods to Numeric objects
		###   class Numeric
		###       include MUES::NumericConstantMethods::Bytes
		###   end
		###
		###   irb> 14.megabytes
		###       ==> 14680064
		###   irb> 188.gigabytes
		###       ==> 201863462912
		###   irb> 177263661663.size_suffix
		###       ==> "165.1G"
		###
		module Bytes

			# Bytes in a Kilobyte
			KILOBYTE = 1024

			# Bytes in a Megabyte
			MEGABYTE = 1024 ** 2

			# Bytes in a Gigabyte
			GIGABYTE = 1024 ** 3

			# Bytes in a Terabyte
			TERABYTE = 1024 ** 4


			### Number of bytes (returns receiver unmodified)
			def bytes
				return self
			end
			alias_method :byte, :bytes

			### Returns the number of bytes in <receiver> kilobytes
			def kilobytes
				return self * 1024
			end
			alias_method :kilobyte, :kilobytes

			### Return the number of bytes in <receiver> megabytes
			def megabytes
				return self * 1024.kilobytes
			end
			alias_method :megabyte, :megabytes

			### Return the number of bytes in <receiver> gigabytes
			def gigabytes
				return self * 1024.megabytes
			end
			alias_method :gigabyte, :gigabytes

			### Return the number of bytes in <receiver> terabytes
			def terabytes
				return self * 1024.gigabytes
			end
			alias_method :terabyte, :terabytes

			### Return the number of bytes in <receiver> petabytes
			def petabytes
				return self * 1024.terabytes
			end
			alias_method :petabyte, :petabytes

			### Return the number of bytes in <receiver> exabytes
			def exabytes
				return self * 1024.petabytes
			end
			alias_method :exabyte, :exabytes

			### Return a human readable file size.
			def size_suffix
				bytes = self.to_f
				return
					if bytes >= TERABYTE 	then "%0.1fT" % bytes / TERABYTE
					elsif bytes >= GIGABYTE then "%0.1fG" % bytes / GIGABYTE
					elsif bytes >= MEGABYTE then "%0.1fM" % bytes / MEGABYTE
					elsif bytes >= KILOBYTE then "%0.1fK" % bytes / KILOBYTE
					else "%db" % [ self ]
					end
			end

		end # module Bytes

	end # module NumericConstantMethods


	### A collection of command-line utility functions
	module UtilityFunctions

		# Set some ANSI escape code constants (Shamelessly stolen from Perl's
		# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
		ANSI_ATTRIBUTES = {
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


		MULTILINE_PROMPT = %Q{Enter one or more values for '%s'.\n} +
			%Q{A blank line finishes input.\n}


		CLEAR_TO_EOL       = "\e[K"
		CLEAR_CURRENT_LINE = "\e[2K"


		### Output a logging message
		def log( *msg )
			output = colorize( msg.flatten.join(' '), 'cyan' )
			$stderr.puts( output )
		end


		### Output a logging message if tracing is on
		def trace( *msg )
			return unless $trace
			output = colorize( msg.flatten.join(' '), 'yellow' )
			$stderr.puts( output )
		end


		### Print an error message and exit with an error code.
		def fail( *messages )
			error_message( "Failed.", messages.join("\n") )
			exit( 255 )
		end


		### Run the specified command +cmd+ with system(), failing if the execution
		### fails.
		def run( *cmd )
			cmd.flatten!
			cmd.collect! {|part| part.to_s }

			if cmd.length > 1
				trace( cmd.collect {|part| part =~ /\s/ ? part.inspect : part} ) 
			else
				trace( cmd )
			end

			if $dryrun
				log "(dry run mode)"
			else
				system( *cmd )
				unless $?.success?
					fail "Command failed: [%s]" % [cmd.join(' ')]
				end
			end
		end


		### Open a pipe to a process running the given +cmd+ and call the given block with it.
		def pipeto( *cmd )
			$DEBUG = true

			cmd.flatten!
			log( "Opening a pipe to: ", cmd.collect {|part| part =~ /\s/ ? part.inspect : part} ) 
			if $dryrun
				log "(dry run mode)"
			else
				open( '|-', 'w+' ) do |io|

					# Parent
					if io
						yield( io )

					# Child
					else
						exec( *cmd )
						fail "Command failed: [%s]" % [cmd.join(' ')]
					end
				end
			end
		end


		### Open a pipe from a process running the given +cmd+ and call the block with the
		### resulting IO object.
		def readfrom( *cmd )
			$DEBUG = true

			cmd.flatten!
			cmd.collect! {|part| part.to_s }
			log( "Opening a pipe from: ", cmd.collect {|part| part =~ /\s/ ? part.inspect : part} ) 

			if $dryrun
				$stderr.puts "(dry run mode)"
			else
				open( '|-', 'r' ) do |io|

					# Parent
					if io
						yield( io )

					# Child
					else
						exec( *cmd )
						fail "Command failed: [%s]" % [cmd.join(' ')]
					end
				end
			end
		end


		### Download the file at +sourceuri+ via HTTP and write it to +targetfile+.
		def download( sourceuri, targetfile=nil )
			oldsync = $defout.sync
			$defout.sync = true
			require 'net/http'
			require 'uri'

			targetpath = Pathname.new( targetfile )

			log "Downloading %s to %s" % [sourceuri, targetfile]
			targetpath.open( File::WRONLY|File::TRUNC|File::CREAT, 0644 ) do |ofh|

				url = sourceuri.is_a?( URI ) ? sourceuri : URI.parse( sourceuri )
				downloaded = false
				limit = 5

				until downloaded or limit.zero?
					Net::HTTP.start( url.host, url.port ) do |http|
						req = Net::HTTP::Get.new( url.path )

						http.request( req ) do |res|
							if res.is_a?( Net::HTTPSuccess )
								log "Downloading..."
								res.read_body do |buf|
									ofh.print( buf )
								end
								downloaded = true
								puts "done."

							elsif res.is_a?( Net::HTTPRedirection )
								url = URI.parse( res['location'] )
								log "...following redirection to: %s" % [ url ]
								limit -= 1
								sleep 0.2
								next

							else
								res.error!
							end
						end
					end
				end

			end

			return targetpath
		ensure
			$defout.sync = oldsync
		end


		### Return the fully-qualified path to the specified +program+ in the PATH.
		def which( program )
			ENV['PATH'].split(/:/).
				collect {|dir| Pathname.new(dir) + program }.
				find {|path| path.exist? && path.executable? }
		end


		### Create a string that contains the ANSI codes specified and return it
		def ansi_code( *attributes )
			attributes.flatten!
			attributes.collect! {|at| at.to_s }
			# $stderr.puts "Returning ansicode for TERM = %p: %p" %
			# 	[ ENV['TERM'], attributes ]
			return '' unless /(?:vt10[03]|xterm(?:-color)?|linux|screen)/i =~ ENV['TERM']
			attributes = ANSI_ATTRIBUTES.values_at( *attributes ).compact.join(';')

			# $stderr.puts "  attr is: %p" % [attributes]
			if attributes.empty? 
				return ''
			else
				return "\e[%sm" % attributes
			end
		end


		### Colorize the given +string+ with the specified +attributes+ and return it, handling 
		### line-endings, color reset, etc.
		def colorize( *args )
			string = ''

			if block_given?
				string = yield
			else
				string = args.shift
			end

			ending = string[/(\s)$/] || ''
			string = string.rstrip

			return ansi_code( args.flatten ) + string + ansi_code( 'reset' ) + ending
		end


		### Output the specified <tt>msg</tt> as an ANSI-colored error message
		### (white on red).
		def error_message( msg, details='' )
			$stderr.puts colorize( 'bold', 'white', 'on_red' ) { msg } + details
		end
		alias :error :error_message


		### Highlight and embed a prompt control character in the given +string+ and return it.
		def make_prompt_string( string )
			return CLEAR_CURRENT_LINE + colorize( 'bold', 'green' ) { string + ' ' }
		end


		### Output the specified <tt>prompt_string</tt> as a prompt (in green) and
		### return the user's input with leading and trailing spaces removed.  If a
		### test is provided, the prompt will repeat until the test returns true.
		### An optional failure message can also be passed in.
		def prompt( prompt_string, failure_msg="Try again." ) # :yields: response
			prompt_string.chomp!
			prompt_string << ":" unless /\W$/.match( prompt_string )
			response = nil

			begin
				prompt = make_prompt_string( prompt_string )
				response = Readline.readline( prompt ) || ''
				response.strip!
				if block_given? && ! yield( response ) 
					error_message( failure_msg + "\n\n" )
					response = nil
				end
			end while response.nil?

			return response
		end


		### Prompt the user with the given <tt>prompt_string</tt> via #prompt,
		### substituting the given <tt>default</tt> if the user doesn't input
		### anything.  If a test is provided, the prompt will repeat until the test
		### returns true.  An optional failure message can also be passed in.
		def prompt_with_default( prompt_string, default, failure_msg="Try again." )
			response = nil

			begin
				default ||= '~'
				response = prompt( "%s [%s]" % [ prompt_string, default ] )
				response = default.to_s if !response.nil? && response.empty? 

				trace "Validating reponse %p" % [ response ]

				# the block is a validator.  We need to make sure that the user didn't
				# enter '~', because if they did, it's nil and we should move on.  If
				# they didn't, then call the block.
				if block_given? && response != '~' && ! yield( response )
					error_message( failure_msg + "\n\n" )
					response = nil
				end
			end while response.nil?

			return nil if response == '~'
			return response
		end


		### Prompt for an array of values
		def prompt_for_multiple_values( label, default=nil )
		    $stderr.puts( MULTILINE_PROMPT % [label] )
		    if default
				$stderr.puts "Enter a single blank line to keep the default:\n  %p" % [ default ]
			end

		    results = []
		    result = nil

		    begin
		        result = Readline.readline( make_prompt_string("> ") )
				if result.nil? || result.empty?
					results << default if default && results.empty?
				else
		        	results << result 
				end
		    end until result.nil? || result.empty?

		    return results.flatten
		end


		### Turn echo and masking of input on/off. 
		def noecho( masked=false )
			require 'termios'

			rval = nil
			term = Termios.getattr( $stdin )

			begin
				newt = term.dup
				newt.c_lflag &= ~Termios::ECHO
				newt.c_lflag &= ~Termios::ICANON if masked

				Termios.tcsetattr( $stdin, Termios::TCSANOW, newt )

				rval = yield
			ensure
				Termios.tcsetattr( $stdin, Termios::TCSANOW, term )
			end

			return rval
		end


		### Prompt the user for her password, turning off echo if the 'termios' module is
		### available.
		def prompt_for_password( prompt="Password: " )
			return noecho( true ) do
				$stderr.print( prompt )
				($stdin.gets || '').chomp
			end
		end


		### Display a description of a potentially-dangerous task, and prompt
		### for confirmation. If the user answers with anything that begins
		### with 'y', yield to the block. If +abort_on_decline+ is +true+,
		### any non-'y' answer will fail with an error message.
		def ask_for_confirmation( description, abort_on_decline=true )
			puts description

			answer = prompt_with_default( "Continue?", 'n' ) do |input|
				input =~ /^[yn]/i
			end

			if answer =~ /^y/i
				return yield
			elsif abort_on_decline
				error "Aborted."
				fail
			end

			return false
		end
		alias :prompt_for_confirmation :ask_for_confirmation


		### Search line-by-line in the specified +file+ for the given +regexp+, returning the
		### first match, or nil if no match was found. If the +regexp+ has any capture groups,
		### those will be returned in an Array, else the whole matching line is returned.
		def find_pattern_in_file( regexp, file )
			rval = nil

			File.open( file, 'r' ).each do |line|
				if (( match = regexp.match(line) ))
					rval = match.captures.empty? ? match[0] : match.captures
					break
				end
			end

			return rval
		end


		### Invoke the user's editor on the given +filename+ and return the exit code
		### from doing so.
		def edit( filename )
			editor = ENV['EDITOR'] || ENV['VISUAL'] || DEFAULT_EDITOR
			system editor, filename
			unless $?.success?
				fail "Editor exited uncleanly."
			end
		end

	end # module UtilityFunctions

	# 
	# A alternate formatter for Logger instances.
	# 
	# == Usage
	# 
	#   require 'treequel/utils'
	#   MUES.logger.formatter = MUES::LogFormatter.new( MUES.logger )
	# 
	# == Version
	#
	#  $Id$
	#
	# == Authors
	#
	# * Michael Granger <ged@FaerieMUD.org>
	#
	# :include: LICENSE
	#
	#--
	#
	# Please see the file LICENSE in the 'docs' directory for licensing details.
	#
	class LogFormatter < Logger::Formatter

		# The format to output unless debugging is turned on
		DEFAULT_FORMAT = "[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"

		# The format to output if debugging is turned on
		DEFAULT_DEBUG_FORMAT = "[%1$s.%2$06d %3$d/%4$s] %5$5s {%6$s} -- %7$s\n"


		### Initialize the formatter with a reference to the logger so it can check for log level.
		def initialize( logger, format=DEFAULT_FORMAT, debug=DEFAULT_DEBUG_FORMAT ) # :notnew:
			@logger       = logger
			@format       = format
			@debug_format = debug

			super()
		end

		######
		public
		######

		# The Logger object associated with the formatter
		attr_accessor :logger

		# The logging format string
		attr_accessor :format

		# The logging format string that's used when outputting in debug mode
		attr_accessor :debug_format


		### Log using either the DEBUG_FORMAT if the associated logger is at ::DEBUG level or
		### using FORMAT if it's anything less verbose.
		def call( severity, time, progname, msg )
			args = [
				time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
				time.usec,                                                    # %2$d
				Process.pid,                                                  # %3$d
				Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
				severity,                                                     # %5$s
				progname,                                                     # %6$s
				msg                                                           # %7$s
			]

			if @logger.level == Logger::DEBUG
				return self.debug_format % args
			else
				return self.format % args
			end
		end
	end # class LogFormatter


	# 
	# A ANSI-colorized formatter for Logger instances.
	# 
	# == Usage
	# 
	#   require 'treequel/utils'
	#   MUES.logger.formatter = MUES::ColorLogFormatter.new( MUES.logger )
	# 
	# == Version
	#
	#  $Id$
	#
	# == Authors
	#
	# * Michael Granger <ged@FaerieMUD.org>
	#
	# :include: LICENSE
	#
	#--
	#
	# Please see the file LICENSE in the 'docs' directory for licensing details.
	#
	class ColorLogFormatter < Logger::Formatter
		extend MUES::ANSIColorUtilities

		# Color settings
		LEVEL_FORMATS = {
			:debug => colorize( :bold, :black ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s {%6$s} -- %7$s\n"},
			:info  => colorize( :normal ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"},
			:warn  => colorize( :bold, :yellow ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"},
			:error => colorize( :red ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"},
			:fatal => colorize( :bold, :red, :on_white ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"},
		}


		### Initialize the formatter with a reference to the logger so it can check for log level.
		def initialize( logger, settings={} ) # :notnew:
			settings = LEVEL_FORMATS.merge( settings )

			@logger   = logger
			@settings = settings

			super()
		end

		######
		public
		######

		# The Logger object associated with the formatter
		attr_accessor :logger

		# The formats, by level
		attr_accessor :settings


		### Log using the format associated with the severity
		def call( severity, time, progname, msg )
			args = [
				time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
				time.usec,                                                    # %2$d
				Process.pid,                                                  # %3$d
				Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
				severity,                                                     # %5$s
				progname,                                                     # %6$s
				msg                                                           # %7$s
			]

			return self.settings[ severity.downcase.to_sym ] % args
		end
	end # class LogFormatter


	# 
	# An alternate formatter for Logger instances that outputs +div+ HTML
	# fragments.
	# 
	# == Usage
	# 
	#   require 'treequel/utils'
	#   MUES.logger.formatter = MUES::HtmlLogFormatter.new( MUES.logger )
	# 
	# == Version
	#
	#  $Id$
	#
	# == Authors
	#
	# * Michael Granger <ged@FaerieMUD.org>
	#
	# :include: LICENSE
	#
	#--
	#
	# Please see the file LICENSE in the 'docs' directory for licensing details.
	#
	class HtmlLogFormatter < Logger::Formatter
		include ERB::Util  # for html_escape()

		# The default HTML fragment that'll be used as the template for each log message.
		HTML_LOG_FORMAT = %q{
		<div class="log-message %5$s">
			<span class="log-time">%1$s.%2$06d</span>
			[
				<span class="log-pid">%3$d</span>
				/
				<span class="log-tid">%4$s</span>
			]
			<span class="log-level">%5$s</span>
			:
			<span class="log-name">%6$s</span>
			<span class="log-message-text">%7$s</span>
		</div>
		}

		### Override the logging formats with ones that generate HTML fragments
		def initialize( logger, format=HTML_LOG_FORMAT ) # :notnew:
			@logger = logger
			@format = format
			super()
		end


		######
		public
		######

		# The HTML fragment that will be used as a format() string for the log
		attr_accessor :format


		### Return a log message composed out of the arguments formatted using the
		### formatter's format string
		def call( severity, time, progname, msg )
			args = [
				time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
				time.usec,                                                    # %2$d
				Process.pid,                                                  # %3$d
				Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
				severity.downcase,                                            # %5$s
				progname,                                                     # %6$s
				html_escape( msg ).gsub(/\n/, '<br />')                       # %7$s
			]

			return self.format % args
		end

	end # class HtmlLogFormatter

end # class MUES

