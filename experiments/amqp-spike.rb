#!/usr/bin/env ruby1.9

require 'bunny'
require 'logger'

class Server < Logger::Application

	BUS_USER = 'engine'
	BUS_PASS = 'Iuv{o8veeciNgoh0'

	def self::start
		return self.new.start
	end

	def initialize
		@playersbus = Bunny.new( :vhost => '/players', :user => BUS_USER, :pass => BUS_PASS )
		@envbus = Bunny.new( :vhost => '/env', :user => BUS_USER, :pass => BUS_PASS )
		@connect_queue = nil
		super( "AMQP Spike Server" )
	end


	def run
		@envbus.start
		@playersbus.start

		# Set up the shared environment
		@room = Room.new( @envbus )

		# Set up the connect queue
		@login_exch = @playersbus.exchange( 'login', :type => :direct, :auto_delete => true )
		@connect_queue = @playersbus.queue( 'connections', :exclusive => true )
		@connect_queue.bind( @login_exch, :key => :character_name )
		@connect_queue.subscribe( :header => true, :consumer_tag => 'engine', :exclusive => true, 
		                          :no_ack => false, &self.method(:handle_client_connect) )
	end


	def halt
		log( DEBUG, "Halting server." )
		@connect_queue.unsubscribe
	end

	def handle_client_connect( event )
		@logger.info "Connect event: %p" % [ event ]
		self.halt
	end

end


class Room

	def initialize( envbus )
	end

end

Server.start

