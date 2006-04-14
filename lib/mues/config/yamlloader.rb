#!/usr/bin/ruby
# 
# This file contains the MUES::Config::YamlLoader class, a derivative of
# MUES::Config::Loader. This is a loader class that loads the configuration from
# a YAML-format file.
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

require 'yaml'

require 'mues/mixins'
require 'mues/object'
require 'mues/config'

module MUES
class Config

	### An object class used to load configuration files written in YAML for the
	### MUES.
	class YamlLoader < MUES::Config::Loader

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		######
		public
		######

		### Load and return configuration values from the YAML +file+
		### specified.
		def load( filename )
			self.log.info "Loading YAML-format configuration from '%s'" % filename
			return YAML::load( File::read(filename) )
		end


		### Save configuration values to the YAML +file+ specified.
		def save( confighash, filename )
			self.log.info "Saving YAML-format configuration to '%s'" % filename
			File::open( filename, File::WRONLY|File::CREAT|File::TRUNC ) {|ofh|
				ofh.print( confighash.to_yaml )
			}
		end


		### Return +true+ if the specified +file+ is newer than the given
		### +time+.
		def isNewer?( file, time )
			return false unless File::exists?( file )
			st = File::stat( file )
			self.log.debug "File mtime is: %s, comparison time is: %s" %
				[ st.mtime, time ]
			return st.mtime > time
		end


	end # class YamlLoader

end # class Config
end # module MUES

