#!/usr/bin/env ruby

require 'mues'
require 'mues/mixins'
require 'mues/constants'

# The main server object class.
class MUES::Engine
    include MUES::Configurable,
	        MUES::Loggable

    config_key :engine

	# The Engine's version-control revision
	VCSREV = %q$Revision$

	### Create a new instance of the Engine.
	def initialize
		
	end


	######
	public
	######

	

end # class MUES::Engine

