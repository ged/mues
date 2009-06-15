#!/usr/bin/env ruby

require 'mues/monkeypatches'
require 'pluginfactory'
require 'uri'

# 
# The MUES::Logger::Outputter class, which is the abstract base class for 
# objects that control where logging output is sent in an MUES::Logger object. 
# 
# == Subversion Id
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
# Please see the file LICENSE in the BASE directory for licensing details.
#
class MUES::Logger::Outputter
	include PluginFactory

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# The default description
	DEFAULT_DESCRIPTION = "Logging Outputter"

	# The default interpolatable string that's used to build the message to
	# output
	DEFAULT_FORMAT =
		%q{#{time.strftime('%Y/%m/%d %H:%M:%S')} [#{level}]: #{name} } +
			%q{#{frame ? '('+frame+')' : ''}: #{msg[0,1024]}}


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Specify the directory to look for the derivatives of this class in.
	def self::derivativeDirs
		["mues/logger"]
	end


	### Parse the given string into a URI object, appending the path part if
	### it doesn't exist.
	def self::parse_uri( str )
		return str if str.is_a?( URI::Generic )
		str += ":." if str.match( /^\w+$/ )
		URI.parse( str )
	end


	### Create a new MUES::Logger::Outputter object of the type specified 
	### by +uri+.
	def self::create( uri, *args )
		uri = self.parse_uri( uri ) if uri.is_a?( String )
		super( uri.scheme.dup, uri, *args )
	end



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new MUES::Logger::Outputter object with the given +uri+,
	### +description+ and sprintf-style +format+.
	def initialize( uri, description=DEFAULT_DESCRIPTION, format=DEFAULT_FORMAT )
		@description = description
		@format = format
	end


	######
	public
	######

	# The outputter's description, for introspection utilities.
	attr_accessor :description

	# The uninterpolated string format for this outputter. This message
	# written will be formed by interpolating this string in the #write
	# method's context immediately before outputting.
	attr_accessor :format


	### Write the given +level+, +name+, +frame+, and +msg+ to the target
	### output mechanism. Subclasses can call this with a block which will
	### be passed the formatted message. If no block is supplied by the
	### child, this method will check to see if $DEBUG is set, and if it is,
	### write the log message to $stderr.
	def write( time, level, name, frame, msg )
		msg = @format.interpolate( binding )

		if block_given?
			yield( msg )
		else
			$stderr.puts( msg ) if $DEBUG
		end
	end


	### Returns a human-readable description of the object as a String
	def inspect
		"#<%s:0x%0x %s>" % [
			self.class.name,
			self.object_id * 2,
			self.inspection_details,
		]
	end


	#########
	protected
	#########

	### Returns a String which should be included in the implementation-specific part 
	### of the object's inspection String.
	def inspection_details
		return "%s (%s)" % [ self.description, self.format ]
	end
	

end # class MUES::Logger::Outputter


