#!/usr/bin/env ruby

require 'verse'
require 'verse/mixins'

require 'mues'
require 'mues/mixins'
require 'mues/constants'


### The shared environment container object -- manages all interaction between the
### Engine and the game environment.
class MUES::Environment
	include MUES::Loggable,
	        MUES::Constants,
	        Verse::SessionObserver,
	        Verse::NodeObserver

	### Create a new Environment that will connect to the .
	def initialize
		
	end


	######
	public
	######


	### Start the environment
	def start
		
	end


	### Stop the environment.
	def stop
	end




end # MUES::Environment


