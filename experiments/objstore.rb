#!/usr/bin/ruby

DRIVER = "Bdb"

require 'mues/player'
require 'mues/objectstore'

p = MUES::Player.new( "localhost" )
p.name( "Eduardo" )

o = MUES::ObjectStore.new( DRIVER, "faeriemud" )

id = o.storeObjects( p )

puts "Got object id back: #{id}"

