#!/usr/bin/ruby
#
# This file contains event classes that are used for sending input or output to
# and from objects within the MUES::Engine. 
#
# The event classes defined in this file are:
#
# [MUES::IOEvent]
#	An abstract base class for Input/Output events.
#
# [MUES::OutputEvent]
#	An output event class.
#
# [MUES::InputEvent]
#	An input event class.
#
# [MUES::IOControlOutputEvent]
#	Abstract OutputEvent class for special output.
#
# [MUES::PromptEvent]
#	Output event class for prompting a user.
#
# [MUES::HiddenInputPromptEvent]
#	Prompt event class for prompting a user and hiding the resultant input.
#
# [MUES::DebugOutputEvent]
#	Output event class for events that carry debugging information.
#
# [MUES::ErrorOutputEvent]
#   Output event class for events that carry error information.
#
# [MUES::FormattedOutputEvent]
#   Output event for data which contains formatting tags.
#
# [MUES::WrappedOutputEvent]
#   Output event for data which should be wrapped to the output device's width.
#
# [MUES::PagedOutputEvent]
#   Output event for data which should be paged.
#
# [MUES::TabularOutputEvent]
#   Output event for tabular data.
#
# == Synopsis
#
#	require 'mues/mixins'
#   require 'mues/events'
#
#	include MUES::ServerFunctions
#
#   # Send a broadcast to all OutputEvent receivers
#   engine.dispatchEvents( OuputEvent.new "The server is shutting down." )
#
# == To Do
#
# * Most of the little classes in this file will eventually be replaced by more
#   intelligent OutputEvent class and one or more Strategies (ala the Strategy
#   Design Pattern from the GoF book) that add additional features for those
#   OutputEventFilters that grok them. This will perhaps eventually look like:
#
#		outputEvent = OutputEvent::new( content, :wrapped, :paged, :formatted )
#
#   The output-sided IOEventFilters would then be free to implement (or not) any
#   capability they
#
# == Rcsid
# 
# $Id: ioevents.rb,v 1.13 2003/10/13 04:02:15 deveiant Exp $
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

require "strscan"

require 'mues/object'
require 'mues/exceptions'

require 'mues/events/event'

module MUES

	### Abstract base class for Input/Output events.
	class IOEvent < Event ; implements MUES::AbstractClass

		### Initialize a new Input or OutputEvent. Should be called from a
		### derivative's initializer.
		def initialize( *args ) # :notnew:
			super()
			@data = args.collect {|m| m.to_s}.join('')
		end

		# The input or output data
		attr_accessor	:data

		### Return the event as a string.
		def to_s
			return "%s: %s" % [ super(), @data ]
		end
	end


	#################################################################
	###	O U T P U T   E V E N T S
	#################################################################

	### Output event class. See MUES::IOEvent.
	class OutputEvent < IOEvent; end


	### Abstract OutputEvent class for special output. This class adds an IO
	### control mode command to the regular OutputEvent which is used to control
	### the mode of display devices which have terminal controls suitable for
	### doing so. This is to support things like pagers, no-echo mode,
	### line-mode, etc.
	class IOControlOutputEvent < OutputEvent ; implements MUES::AbstractClass
	end


	### Output event class for prompting a user. A terminal client may just
	### print this prompt directly, while a graphical client may display a
	### dialog box and use the event's contents as the prompt message.
	class PromptEvent < IOControlOutputEvent

		### Create and return a new PromptEvent with the specified prompt
		### string.
		def initialize( arg="mues> " )
			super( arg )
		end
	end # class PromptEvent


	### Prompt event class for prompting a user and hiding the resultant
	### input. This is useful for prompting for secret or hidden input values
	### such as passwords or other data which should not be visible to a third
	### party. A telnet terminal may simply hide the input with the 'ECHO'
	### option, while a graphical client may wish to present a dialog which
	### displays asterisks for each character (or something).
	class HiddenInputPromptEvent < PromptEvent; end


	### Derivative of the MUES::OutputEvent class for events that carry debugging
	### information. <em>Currently unused.</em>
	class DebugOutputEvent < OutputEvent ; end


	### Derivative of the MUES:::OutputEvent class for events that carry
	### information meant to be displayed as an error.
	class ErrorOutputEvent < OutputEvent ; end


	### This class is a derivative of MUES::OutputEvent, instances of which
	### encapsulate output data which has been marked up with formatting XML
	### tags.
	###
	### The following tags are supported:
	###
	### == Formatting tags
	### [<tt>&lt;b&gt;</tt>, <tt>&lt;strong&gt;</tt>]
	###   The text should be displayed as bold or double-strike.
	###
	### [<tt>&lt;ul&gt;</tt>]
	###   The text should be displayed as underlined.
	###
	### == Color tags
	### [<tt>&lt;<em>color</em>&gt;</tt>]
	###   The text should be displayed in the specified color, which may be one
	###   of the following: black, red, green, yellow, blue, magenta, cyan, or
	###   white.
	### [<tt>&lt;on_<em>color</em>&gt;</tt>]
	###   The text should be displayed on a background of the specified color,
	###   which may be one of the following: black, red, green, yellow, blue,
	###   magenta, cyan, or white.
	###
	### Handlers which provide some or all of the formatting which can be
	### specified by this type of event should use the #formattedData method,
	### while those that do not should use the usual #data accessor.
	class FormattedOutputEvent < OutputEvent

		### Create and return a FormattedOutputEvent which encapsulates the
		### specified formatted data.
		def initialize( data )
			strippedData = data.gsub( %r{</?[^>]+>}, '' )
			super( strippedData )
			@formattedData = data
		end


		######
		public
		######

		# The formatted version of the event's data
		attr_reader :formattedData

	end # class FormattedOutputEvent


	### This class is a derivative of MUES::OutputEvent, instances of which
	### encapsulate data which should be wrapped to fit within the output device
	### it will be displayed on, if possible.
	###
	### Handlers which provide wrapped output should call the #lines method to
	### retrieve the event's data, while those that do not implement wrapped
	### functionality themselves can use the usual #data interface. If an
	### argument is given to the #data method it will used as a character width
	### to wrap to; otherwise the method will return the event's lines wrapped
	### to 80 columns.
	###
	### Some output devices may wish to separate each event data line with a
	### blank space, but this is not required, nor should it be relied upon for
	### layout purposes.
	class WrappedOutputEvent < OutputEvent

		### Create and return a new WrappedOutputEvent with the specified data
		### lines (objects which support the #to_s method). Each argument given
		### to the constructor is considered a distinct line, and will be
		### wrapped to an appropriate width by the receiving handler.
		def initialize( *lines )
			@lines = lines.collect {|line| line.to_s}
			@data  = {}
		end


		### Return the event's lines wrapped to the specified column
		### <tt>width</tt>.
		def data( width=80 )
			width = width.to_i

			# If we don't have a copy of the data wrapped to the specified width
			# yet, build it.
			unless @data.key? width
				newLines = []

				@lines.each {|line|
					
				}
			end

			@data[width]
		end


		#########
		protected
		#########

		### Wrap the specified +text+ to the specified +width+.
		def wrap( text, width=80 )

			# Split the lines up by line-endings
			lines = text.split( /\n/ )
			wrappedLines = []
			
			# Iterate over each line, building a wrapped line array of each one.
			lines.each {|line|
				debugMsg( "Scanning line '#{line}'" )
				wrappedLines.push WrappedLineArray::new( width )
				scanner = StringScanner::new( line, true )

				# While there's text left to scan, try to match a word preceeded
				# by optional whitespace. If we don't find that, just eat one
				# character and add that.
				while scanner.rest?
					appendText = scanner.scan( /\A\s*\S+/ ) || scanner.getch
					wrappedLines.last.append( appendText )
				end
			}
			
			# Now join all the lines back together with line-endings.
			return wrappedLines.collect {|wla| wla.lines.join("\n")}.join("\n")
		end


		### This is a little utility class that does line-wrapping to a given
		### width. It's used by the #wrap method.
		class WrappedLineArray # :nodoc:

			### Instantiate and return a new WrappedLineArray that will wrap any
			### data given to it to the specified <tt>width</tt>.
			def initialize( width=80 )
				@width = width
				@lines = ['']
			end

			# The wrapped lines
			attr_accessor :lines

			### Append the specified <tt>chars</tt> to the array of lines,
			### adding a new one if necessary.
			def append( chars )
				if chars.length + @lines.last.length > @width
					@lines.push( '' )
					chars.strip!
				end

				@lines[-1] += chars
			end

		end # class WrappedLineArray
	end # class WrappedOutputEvent


	### This class is a derivative of MUES::OutputEvent, instances of which
	### encapsulate data which is a "page" or more in length, and should be
	### displayed in a way which allows the User to read it in a paged display
	### of some sort. Since there is no reliable way to determine what a "page"
	### is from the systems which will tend to generate the text which will
	### exceed it, it is left to the discretion of the implementor as to when it
	### is appropriate to use this type of event as opposed to a plain
	### OutputEvent.
	class PagedOutputEvent < OutputEvent ; end


	### This class is a derivative of MUES::OutputEvent, instances of which
	### encapsulate data which should be displayed in a tabular format. It isn't
	### implemented yet.
	class TabularOutputEvent < OutputEvent ; end



	#################################################################
	###	I N P U T   E V E N T S
	#################################################################

	### Input event class. See MUES::IOEvent.
	class InputEvent < IOEvent; end



end # module MUES

