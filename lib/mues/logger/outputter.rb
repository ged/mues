#!/usr/bin/ruby
# 
# This file contains the MUES::Logger::Outputter class, which is the abstract
# base class for objects that control where logging output is sent in an
# MUES::Logger object. 
# 
# == Subversion ID
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'pluginfactory'

require 'mues/utils'
require 'mues/logger'
require 'mues/mixins'

module MUES
class Logger

	### This class is the abstract base class for logging outputters for
	### MUES::Logger.
	class Outputter < ::Object
		include PluginFactory

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# The default description
		DefaultDescription = "Logging Outputter"

		# The default interpolatable string that's used to build the message to
		# output
		DefaultFormat =
			%q{#{time} [#{level}]: #{name} #{frame ? '('+frame+')' : ''}: #{msg[0,1024]}}


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Specify the directory to look for the derivatives of this class in.
		def self::derivativeDirs
			["mues/logger"]
		end


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new MUES::Logger::Outputter object that will write to the
		### specified +io+ object, using the given +formatter+ (an
		### MUES::Logger::Formatter object). The specified +description+ will
		### be used for introspection tools.
		def initialize( description=DefaultDescription, format=DefaultFormat )
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
		### write the log message to $deferr.
		def write( time, level, name, frame, msg )
			msg = @format.interpolate( binding )

			if block_given?
				yield( msg )
			else
				$deferr.puts( msg ) if $DEBUG
			end
		end


	end # class Outputter

end # class Logger
end # module MUES


