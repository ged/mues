#!/usr/bin/env ruby

require 'mues'
require 'mues/mixins'
require 'mues/constants'

# The main server object class.
class MUES::Engine
    include MUES::Constants,
	        MUES::Loggable

	# The Engine's version-control revision
	VCSREV = %q$Revision$

	# The user to use when connecting to amqp
	BUS_USER = 'engine'

	# The name of the vhost that will be used to communicate with players.
	PLAYERS_VHOST = '/players'

	# The name of the vhost that will be used for environment events.
	ENVIRONMENT_VHOST = '/env'


	### Create a new Engine and start it, returning the ThreadGroup containing
	### all of its threads.
	def self::start
		return self.new.start
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Engine object
	def initialize
		self.log.debug "New engine created."

		# AMQP virtualhost connections
		@playersbus     = nil
		@envbus         = nil

		# Event queues and exchanges
		@connect_queue  = nil
		@login_exch     = nil

		# Threads and thread groups
		@engine_threads = ThreadGroup.new
		@parent_thread  = nil
	end


	### Start the engine
	def start
		@parent_thread = Thread.new do
			self.log.debug "Starting the Engine..."
			Thread.current.abort_on_exception = true

			self.start_environment_bus
			self.start_player_bus

			# Set up the shared environment
			# @room = Room.new( @envbus )

		end

		@engine_threads.add( @parent_thread )
	end


	def stop
		log( NOTICE, "Stopping the Engine." )

		self.stop_player_bus
		self.stop_environment_bus

		@players.each do |pl|
			pl.disconnect
		end
	end



	#########
	protected
	#########

	### Start the connections to AMQP for the environment.
	def start_environment_bus
		self.log.notice "Creating the environment event bus."
		@envbus = Bunny.new(
			:vhost => ENVIRONMENT_VHOST,
			:user  => BUS_USER,
			:pass  => BUS_PASS
		  )

		self.log.debug "  starting..."
		@envbus.start
	end


	### Stop propagating events in the environment
	def stop_environment_bus
		self.log.notice "Stopping the environment event bus."
		@envbus.stop
	end


	### Start the connections to AMQP for communication with players.
	def start_player_bus
		self.log.notice "Creating the players event bus."
		@playersbus = Bunny.new(
			:vhost => PLAYERS_VHOST,
			:user  => BUS_USER,
			:pass  => BUS_PASS
		  )

		self.log.debug "  starting..."
		@playersbus.start

		# Set up the exchange player clients will use for logging in
		self.log.debug "  setting up the login exchange..."
		@login_exch = @playersbus.exchange( 'login',
			:type        => :direct,
			:auto_delete => true
		  )

		# Set up the queue to handle incoming connections
		self.log.debug "  setting up the connections queue..."
		@connect_queue = @playersbus.queue( 'connections', :exclusive => true )
		@connect_queue.bind( @login_exch, :key => :character_name )
		@connect_queue.subscribe(
			:header       => true,
			:consumer_tag => 'engine',
			:exclusive    => true,
			:no_ack       => false,
			&self.method(:handle_client_connect)
		  )
	end


	### Stop accepting incoming connections
	def stop_player_bus
		self.log.notice "Stopping the player event bus."
		@connect_queue.unsubscribe
		@connect_queue.unbind
		@connect_queue.delete

		@playersbus.stop
	end


	### Handle an incoming connection event: Read the username from the connect 
	### event and set up a client thread for the corresponding exchange.
	def handle_client_connect( event )
		header, details, payload = event.values_at( :header, :delivery_details, :payload )
		playername = payload.strip

		log( INFO, "Trying to connect to the #{playername} exchange." )
		exch = @playersbus.exchange( playername, :passive => true )
		queue = @playersbus.queue( "#{playername}_commands", 
			:durable => true, :exclusive => true, :auto_delete => true )
		queue.bind( exch, :key => 'command.#' )

		player = Player.new( playername, queue, exch )

		thr = player.start
		@players[ playername ] = player
		@player_threads.add( thr )
	rescue => err
		self.log.error "Connection event failed: %s: %s" % [ err.class.name, err.message ]
		self.log.debug {
			err.backtrace.collect {|frame| "  #{frame}" }.join( $/ )
		}
	end

end # class MUES::Engine

