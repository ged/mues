#!/usr/bin/ruby
# 
# This file contains the MUES::Logger::FileOutputter class, a derivative of
# MUES::Logger::Outputter. This is a logger outputter that writes to a
# file or other filehandle.
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

require 'mues/logger'
require 'stringio'

module MUES
class Logger

	### This is an MUES::Logger::Outputter that writes to an IO object.
	class FileOutputter < MUES::Logger::Outputter

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# The default description
		DefaultDescription = "File Outputter"

		# The default format (copied from the superclass)
		DefaultFormat = MUES::Logger::Outputter::DefaultFormat


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new MUES::Logger::FileOutputter object. The +io+ argument
		### can be an IO or StringIO object, in which case output is sent to it
		### directly, a String, in which case it is used as the first argument
		### to File::open, or an Integer file descriptor, in which case a new IO
		### object is created which appends to the file handle matching that
		### descriptor.
		def initialize( io, description=DefaultDescription, format=DefaultFormat )
			case io
			when IO, StringIO
				@io = io
			when String
				@io = File::open( io, File::WRONLY|File::CREAT )
			when Integer
				@io = IO::new( io, 'a' )
			else
				raise TypeError, "Illegal argument 1: %p" %
					io.class.name
			end

			super( description, format )
		end


		######
		public
		######

		# The filehandle open to the logfile
		attr_accessor :io


		### Write the given +level+, +name+, +frame+, and +msg+ to the logfile.
		def write( time, level, name, frame, msg )
			super {|msg|
				@io.puts( msg )
			}
		end

	end # class FileOutputter

end # class Logger
end # module MUES


