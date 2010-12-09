#!/usr/bin/env ruby

require 'mues'
require 'mues/mixins'
require 'mues/constants'

# The main server object class.
class MUES::Player
    include MUES::Constants,
	        MUES::Loggable

	### Create a player from the information in the specified +event+ and
	### connect it to the given +playersbus+.
	def self::new_from_connect_event( event )
		header, details, payload = event.values_at( :header, :delivery_details, :payload )
		name = payload.strip
		return self.new( name, header, details )
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Player object for the player with the given +name+.
	def initialize( name, header, details )
		@name     = name
		@header   = header
		@details  = details

		@exchange = nil
		@queue    = nil
		@thread   = nil
	end


	######
	public
	######

	# The player's name
	attr_reader :name

	# The AMQP header of the connection event
	attr_reader :header

	# The "delivery details" of the connection event
	attr_reader :details

	# The Bunny::Exchange object that is connected to the players bus
	attr_accessor :exchange

	# The Bunny::Queue object that is bound to the exchange, and accumulates
	# command events from the player's client
	attr_accessor :queue


	### Connect the player to the specified +playerbus+.
	def connect_to_bus( playersbus )
		name = self.name
		self.log.info "Trying to connect to the exchange for #{name}."

		self.exchange = playersbus.exchange( name, :passive => true )
		self.queue = playersbus.queue( "#{name}_commands",
			:durable => true, :exclusive => true, :auto_delete => true )
		self.queue.bind( self.exchange, :key => 'command.#' )
	end


	### Start handling events.
	def start
		@thread = Thread.new do
			Thread.current.abort_on_exception = true
			self.queue.subscribe(
				:header       => true,
				:consumer_tag => self.name,
				:exclusive    => true,
				:no_ack       => false,
				&self.method(:handle_command_event)
			  )
		end
	end


	### Stop handling events and destroy the queue and exchange associated with the
	### player.
	def disconnect
		queue = self.queue

		queue.unsubscribe( :consumer_tag => self.name )
		queue.unbind( self.exchange )
		queue.delete

		self.exchange.delete
	end


	#########
	protected
	#########

	### Command event-handler: parse an incoming command, then create and propagate any
	### resulting events.
	def handle_command_event( event )
		self.log.debug "<%s>: command event: %p" % [ self.name, event ]
		header, details, payload = event.values_at( :header, :delivery_details, :payload )
		command = payload.strip

		if command =~ /^(quit|logout)\b/i
			self.log.info "Temporary logout command invoked by '%s'." % [ self.name ]
			self.disconnect
		end

		self.log.debug "Would have run a command: %p" % [ command ]
	end


end # class MUES::Player

