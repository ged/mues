#!/usr/bin/env ruby-1.9.1

require 'bunny'
require 'logger'

class Server

	BUS_USER = 'engine'
	BUS_PASS = 'Iuv{o8veeciNgoh0'

	def self::start
		return self.new.run
	end

	def initialize
		@playersbus = Bunny.new( :vhost => '/players', :user => BUS_USER, :pass => BUS_PASS )
		@envbus = Bunny.new( :vhost => '/env', :user => BUS_USER, :pass => BUS_PASS )
		@connect_queue = nil
		@logger = Logger.new
	end


	def run
		@envbus.start
		@playersbus.start

		# Set up the connect queue
		@login_exch = @playersbus.exchange( 'login', :type => :direct, :auto_delete => true )
		@connect_queue = @playersbus.queue( 'connections', :exclusive => true )
		@connect_queue.bind( @login_exch, :key => 'playername' )
		@connect_queue.subscribe( :header => true, :consumer_tag => 'engine', :exclusive => true, 
		                          :no_ack => false, &self.method(:handle_client_connect) )

		# Set up the shared environment
		@room = Room.new( @envbus )

	end


	def handle_client_connect( event )
		@logger.info "Connect: %s" % [ event ]

	end
end



class Agent

	def initialize( playersbus, envbus )
		@
	end

end


class Room

	def initialize( envbus )
		@
	end

end


