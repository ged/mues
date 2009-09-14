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

user = 'testplayer'
pass = 'test'

broker = Bunny.new( :vhost => '/players', :user => user, :pass => pass, :logging => true )
broker.start

connect_exchange = broker.exchange( 'login', :type => :direct, :auto_delete => true )
connect_exchange.publish( 'ged', :key => :character_name, :mandatory => true )


