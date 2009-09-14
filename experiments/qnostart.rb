#!/usr/bin/env ruby

require 'pp'
require 'bunny'

# An experiment to see if you can avoid calling 'start' on a new Bunny.

amqp = Bunny.new
amqp.start # Bombs if you don't call this explicitly. ugh.

q = amqp.queue( 'chunker' )
ex = amqp.exchange( 'log', :type => :topic )

q.bind( ex, :key => 'apache.*' )

pp q.pop

