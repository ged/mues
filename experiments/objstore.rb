#!/usr/bin/ruby

DRIVER = "Bdb"

require "mues/Player"
require "mues/ObjectStore"

p = MUES::Player.new( "localhost" )
p.name( "Eduardo" )

o = MUES::ObjectStore.new( DRIVER, "faeriemud" )

id = o.storeObjects( p )

puts "Got object id back: #{id}"

