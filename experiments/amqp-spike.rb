#!/usr/bin/env ruby1.9

BEGIN {
	require 'pathname'
	basedir = Pathname(__FILE__).dirname.parent
	srcdir = basedir.parent
	bunnylib = srcdir + 'bunny/lib'

	$LOAD_PATH.unshift( bunnylib.to_s )
}

require 'bunny'
require 'logger'
require 'pp'

class Server < Logger::Application

	BUS_USER = 'engine'
	BUS_PASS = 'Iuv{o8veeciNgoh0'

	def self::start
		return self.new.start
	end

	def initialize
		@playersbus = Bunny.new(
			:vhost => '/players',
			:user => BUS_USER,
			:pass => BUS_PASS
		  )
		@envbus = Bunny.new(
			:vhost => '/env',
			:user => BUS_USER,
			:pass => BUS_PASS
		  )
		@connect_queue = nil
		@client_threads = ThreadGroup.new

		super( "AMQP Spike Server" )
	end


	def run
		@envbus.start
		@playersbus.start

		# Set up the shared environment
		@room = Room.new( @envbus )

		# Set up the connect queue
		@login_exch = @playersbus.exchange( 'login',
			:type => :direct, :auto_delete => true )
		@connect_queue = @playersbus.queue( 'connections', :exclusive => true )
		@connect_queue.bind( @login_exch, :key => :character_name )
		@connect_queue.subscribe( :header => true, :consumer_tag => 'engine',
		                          :exclusive => true, :no_ack => false,
		                          &self.method(:handle_client_connect) )
	end


	def halt
		log( NOTICE, "Halting server." )
		@connect_queue.unsubscribe
		@connect_queue.unbind

		@players.each do |pl|
			pl.disconnect
		end
	end

	# Read the username from the connect event and set up a client thread for the
	# corresponding exchange.
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
	end

end


class Player

	def initialize( name, queue, exchange )
		@name = name
		@queue = queue
		@exchange = exchange

		@thread = nil
	end

	def start
		@thread = Thread.new do
			@queue.subscribe( :header => true, &self.method(:input_handler) )
		end
	end

	def disconnect
		@queue.unsubscribe
		@thread.join
	end

	def input_handler( event )
		pp event
	end

end

class Room

	def initialize( envbus )
	end

end

Server.start

