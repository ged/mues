#!/usr/bin/env ruby1.9

BEGIN {
	require 'pathname'
	basedir = Pathname(__FILE__).dirname.parent
	srcdir = basedir.parent
	bunnylib = srcdir + 'bunny/lib'

	$LOAD_PATH.unshift( bunnylib )
}

require 'bunny'
require 'readline'
require ''

user = readline( "login: " )
pass = prompt_for_password( "password: " )
char = readline( "character: " )

# Open the connection to the AMQP broker
broker = Bunny.new( :vhost => '/players', :user => user, :pass => pass, :logging => true )
broker.start

# Create the player's exchange and start listening for events on it
player_exch = broker.exchange( user, :durable => true, :auto_delete => true )
player_queue = broker.queue( "#{user}", :exclusive => true )

# Publish a request for connection to the specified character
connect_exchange = broker.exchange( :login, :passive => true )
connect_exchange.publish( "#{user}:#{char}",
	:key => :character_name, :mandatory => true )
msg = broker.returned_message

# If the event was published okay, start the client
if msg == :no_return
	$stderr.puts "Connection failed"
else

	# Start a thread that prints incoming events
	t1 = Thread.new do
		Thread.current.abort_on_exception = true
		player_queue.subscribe( :header => true, :consumer_tag => 'client', 
			:exclusive => true, :no_ack => false ) do |event|
			$stderr.puts "Event: #{event}"
		end
	end

	# Start a thread that prompts for commands
	t2 = Thread.new do
		Thread.current.abort_on_exception = true
		while cmd = readline( '> ' )
			cmd.strip!
			case cmd
			when ''
				$stderr.puts
			when /^q(uit)?/i
				$stderr.puts ">>> Quitting."
				player_queue.unsubscribe
				player_queue.delete
				player_exch.delete
			else
				player_exch.publish( cmd, :key => :command )
				$stderr.puts "sent."
			end
		end
	end
end



### Turn echo and masking of input on/off. 
def noecho( masked=false )
	require 'termios'

	rval = nil
	term = Termios.getattr( $stdin )

	begin
		newt = term.dup
		newt.c_lflag &= ~Termios::ECHO
		newt.c_lflag &= ~Termios::ICANON if masked

		Termios.tcsetattr( $stdin, Termios::TCSANOW, newt )

		rval = yield
	ensure
		Termios.tcsetattr( $stdin, Termios::TCSANOW, term )
	end

	return rval
end


### Prompt the user for her password, turning off echo if the 'termios' module is
### available.
def prompt_for_password( prompt="Password: " )
	return noecho( true ) do
		$stderr.print( prompt )
		($stdin.gets || '').chomp
	end
end


