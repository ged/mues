#!/usr/bin/env ruby

require 'mues'
require 'mues/mixins'
require 'mues/constants'

# The main server object class.
class MUES::Engine
    include MUES::Configurable,
	        MUES::Loggable

    config_key :engine


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


end # class MUES::Engine

