#!/usr/bin/env ruby

require 'bunny'

require 'mues'
require 'mues/mixins'
require 'mues/constants'
require 'mues/environment'


# The main server object class.
class MUES::Engine
    include MUES::Constants,
	        MUES::Loggable

	# The Engine's version-control revision
	VCSREV = %q$Revision$

	# The default configuration
	DEFAULT_CONFIG = {
		:mq_user       => DEFAULT_MQ_USER,
		:mq_pass       => DEFAULT_MQ_PASS,
		:players_vhost => DEFAULT_PLAYERS_VHOST,
		:env_vhost     => DEFAULT_ENVIRONMENT_VHOST,
	}


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Engine object
	def initialize( config={} )
		self.log.debug "New engine created."
		@config = DEFAULT_CONFIG.merge( config )
		self.log.debug "  engine config is: %p" % [ @config ]

		players_vhost, env_vhost, user, password =
			@config.values_at( :players_vhost, :env_vhost, :mq_user, :mq_pass )

		# AMQP virtualhost connections
		@playersbus     = Bunny.new( :vhost => players_vhost, :user => user, :pass => password )
		@envbus         = Bunny.new( :vhost => env_vhost, :user => user, :pass => password )

		# Event queues and exchanges
		@connect_queue  = nil
		@login_exch     = nil

		# Threads and thread groups
		@threadgroup    = ThreadGroup.new
		@connect_thread = nil
		@env_thread     = nil

		# The environment object
		@environment    = nil

		# The hash of connected players
		@players        = {}
	end


	######
	public
	######

	# The engine's configuration
	attr_reader :config

	# The thread that handles event-propagation into and out of the Environment
	attr_accessor :env_thread

	# The thread that handles incoming connections
	attr_accessor :connect_thread

	# The ThreadGroup that contains the engine's threads
	attr_reader :threadgroup

	# The MUES::Environment that is running the game world
	attr_reader :environment


	### Start the engine
	def start
		self.log.debug "Starting the Engine..."
		self.set_signal_handlers

		vhost, user, pass = self.config.values_at( :env_vhost, :mq_user, :mq_pass )
		self.start_environment_bus( vhost, user, pass )

		# Set up the shared environment
		self.env_thread = Thread.new do
			Thread.current.abort_on_exception = true
			self.log.debug "  creating the environment object and starting it..."
			@environment = MUES::Environment.new( @envbus )
			@environment.start
		end
		self.threadgroup.add( self.env_thread )

		# Set up the connection-handler
		self.connect_thread = Thread.new do
			Thread.current.abort_on_exception = true
			self.log.debug "  setting up the connection-handler"
			self.start_player_bus( vhost, user, pass )
		end
		self.threadgroup.add( self.connect_thread )

		return self.env_thread
	end


	### Stop the engine and disconnect all players.
	def stop
		self.unset_signal_handlers
		self.log.info "Stopping the Engine."

		@environment.stop

		self.stop_player_bus
		self.stop_environment_bus

		@players.each do |name, pl|
			self.log.info "  disconnecting player %s" % [ name ]
			pl.disconnect
		end
	end



	#########
	protected
	#########

	### Set up various signals to shut down/reload the engine.
	def set_signal_handlers
		stop_handler = lambda {|*args|
			self.log.error "Stopping the engine: %p" % [ args ]
			self.stop
		}

		Signal.trap( :TERM, &stop_handler )
		Signal.trap( :INT, &stop_handler )
		Signal.trap( :HUP, &stop_handler )
	end


	### Restore default signal handlers.
	def unset_signal_handlers
		Signal.trap( :TERM, :SIG_DFL )
		Signal.trap( :INT, :SIG_DFL )
		Signal.trap( :HUP, :SIG_DFL )
	end


	### Start the connections to AMQP for the environment using the specified +vhost+, 
	### +user+, and +password+.
	def start_environment_bus( vhost, user, password )
		self.log.debug "Starting the environment event bus..."
		@envbus.start
	end


	### Stop propagating events in the environment
	def stop_environment_bus
		self.log.info "Stopping the environment event bus."
		@envbus.stop
	end


	### Start the connections to AMQP for communication with players.
	def start_player_bus( vhost, user, password )
		self.log.debug "Starting the players event bus..."
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
			&self.method(:handle_connect_event)
		  )
	end


	### Stop accepting incoming connections
	def stop_player_bus
		self.log.info "Stopping the player event bus."
		@connect_queue.unsubscribe( :consumer_tag => 'engine' )
		@connect_queue.unbind( @login_exch, :key => :character_name )
		@connect_queue.delete

		@playersbus.stop
	end


	### Handle an incoming connection event: Read the username from the connect 
	### event and set up a client thread for the corresponding exchange.
	def handle_connect_event( event )
		player = Player.new_from_connect_event( event )
		player.connect_to_bus( @playersbus )
		@players[ playername ] = player

		thr = player.start
		@player_threads.add( thr )
	rescue => err
		self.log.error "Connection event failed: %s: %s" % [ err.class.name, err.message ]
		self.log.debug {
			err.backtrace.collect {|frame| "  #{frame}" }.join( $/ )
		}
	end

end # class MUES::Engine

