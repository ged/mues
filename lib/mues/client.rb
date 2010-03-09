#!/usr/bin/env ruby

require 'bunny'

require 'mues'
require 'mues/mixins'
require 'mues/constants'

# A reference implementation of a MUES client.

class MUES::Client
	include MUES::Loggable,
	        MUES::Constants

	### Create a new client that will connect to the given +host+ using the specified 
	### +playername+ and +password+.
	def initialize( host, playername, password, vhost=DEFAULT_PLAYERS_VHOST )
		@host       = host
		@playername = playername
		@password   = password
		@vhost      = vhost

		@exchange   = nil
		@queue      = nil

		@client     = Bunny.new(
			:host  => host,
			:vhost => vhost,
			:user  => playername,
			:pass  => password
		  )
	end


	######
	public
	######



	### Connect to the server's player event bus.
	def connect
		@client.start
		@exchange = @client.exchange( @playername, :passive => false )
		@queue = @client.queue( "#{@playername}_output", :exclusive => true )

		login_exchange = @client.exchange( 'login', :type => :direct, :auto_delete => true )

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


end # class MUES::Client

