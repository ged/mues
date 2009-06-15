#!/usr/bin/ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'mues'
require 'mues/logger'
require 'mues/logger/outputter'
require 'mues/mixins'

# 
# Some helper functions for RSpec specifications
# 
module MUES::SpecHelpers

	class ArrayLogOutputter < MUES::Logger::Outputter
		include MUES::HTMLUtilities

		FORMAT = %q{
		<dd class="log-message #{level}">
			<span class="log-time">#{time.strftime('%Y/%m/%d %H:%M:%S')}</span>
			<span class="log-level">#{level}</span>
			:
			<span class="log-name">#{escaped_name}</span>
			<span class="log-frame">#{frame ? '('+frame+'): ' : ''}</span>
			<span class="log-message-text">#{escaped_msg}</span>
		</dd>
		}

		### Create a new ArrayLogOutputter that will append content to +array+.
		def initialize( array )
			super( 'arraylogger', 'Array Logger', FORMAT )
			@array = array
		end

		attr_accessor :array

		### Write the specified +message+ to the array.
		def write( time, level, name, frame, msg )
			escaped_msg = escape_html( msg )
			escaped_name = escape_html( name )
			html = @format.interpolate( binding )

			@array << html
		end

	end # class ArrayLogger


	# The default logging level for reset_logging/setup_logging
	DEFAULT_LOG_LEVEL = :crit

	### Remove any outputters and reset the level to DEFAULT_LOG_LEVEL
	def reset_logging
		MUES::Logger.reset
	end

	### Set up an HTML log outputter at the specified +level+ that's been tailored to SpecMate 
	### output.
	def setup_logging( level=DEFAULT_LOG_LEVEL )
		reset_logging()
		description = "`%s' spec" % [ @_defined_description ]
		outputter = nil

		# Only do this when executing from a spec in TextMate
		if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
			Thread.current['logger-output'] = []
			outputter = ArrayLogOutputter.new( Thread.current['logger-output'] )
		else
			outputter = MUES::Logger::Outputter.create( 'color:stderr', description )
		end

		MUES::Logger.global.outputters << outputter
		MUES::Logger::global.level = level
	end

end


