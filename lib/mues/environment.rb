#!/usr/bin/env ruby

require 'mues'
require 'mues/mixins'
require 'mues/constants'

require 'fm'
require 'fm/area'


### The shared environment container object -- manages all interaction between the
### Engine and the game environment.
class MUES::Environment
	include MUES::Loggable,
	        MUES::Constants

	### Create a new Environment that will communicate over the specified +eventbus+.
	def initialize( eventbus )
		@eventbus = eventbus
		@world = FaerieMUD::Area.new

		@exchange = @eventbus.exchange( 'world', :type => :fanout )
		@queue = @eventbus.queue( 'world', :exclusive => true )
		@queue.bind( @exchange )
	end


	######
	public
	######

	# The environment's event bus
	attr_reader :eventbus

	# The object's event exchange
	attr_reader :exchange


	### Start the environment
	def start
		self.log.info "Starting the environment."

		# Set up the queue to handle incoming connections
		self.log.debug "  subscribing to the connect queue..."
		@queue.subscribe(
			:header       => true,
			:consumer_tag => 'world',
			:exclusive    => true,
			:no_ack       => true,
			&self.method(:handle_world_event)
		  )
	end


	### Stop the environment.
	def stop
		self.log.info "Stopping the environment."
		@queue.unsubscribe( :consumer_tag => 'world' )
		@queue.unbind( self.exchange )
		@queue.delete
		self.log.info "  environment stopped."
	end


	### Handle an event sent to the world by the environment.
	def handle_world_event( event )
		self.log.debug "Handling a world event: %p" % [ event ]
		header, details, payload = event.values_at( :header, :delivery_details, :payload )

		
	end


end # MUES::Environment


