#!/usr/bin/env ruby

require 'mues'
require 'mues/mixins'
require 'mues/constants'

### The shared environment container object -- manages all interaction between the
### Engine and the game environment.
class MUES::Environment
	include MUES::Loggable,
	        MUES::Constants

	### Create a new Environment that will communicate over the specified +eventbus+.
	def initialize( eventbus )
		@bus = eventbus
	end


	######
	public
	######

	# The environment's event bus
	attr_reader :bus


	### Start the environment
	def start
		self.log.notice "Starting the environment."
	end


end # MUES::Environment