#!/usr/bin/ruby -w

require 'mues/player'
require "tableadapter/Mysql"
require "md5"

$DEBUG = true

def MuesAdapterClass( table )
	TableAdapterClass( "mues", table, "deveiant", "3l3g4nt", "" )
end

class PlayerRecord < MuesAdapterClass( "player" ); end

$stderr.puts "Creating new user."
player = PlayerRecord.new

# Field				Type						Null			Key			Default			Extra
# id					int(10) unsigned						PRI			NULL			auto_increment
# ts					timestamp(12)			YES			NULL
# username			varchar(50)				UNI
# cryptedPass		varchar(20)
# realname			varchar(75)				YES			NULL
# emailAddress		varchar(75)				YES			NULL
# lastLogin			datetime					YES			NULL
# lastHost			varchar(75)				YES			NULL
# dateCreated		datetime					YES			NULL
# age					int(10) unsigned						0
# role				tinyint(3) unsigned					0
# flags				int(10) unsigned						0
# preferences		blob						YES			NULL
# characters		blob						YES			NULL


$stderr.puts "Configuring user."
player.username = 'ged'
player.cryptedPass = MD5.new( "3l3g4nt" ).hexdigest
player.realname = "Michael Granger"
player.emailAddress = "ged@FaerieMUD.org"
player.lastLogin = '2001-03-01 01:00:00'
player.lastHost = 'localhost'
player.dateCreated = '2001-03-01 01:00:00'
player.age = 4
player.role = MUES::Player::Role::ADMIN
player.preferences = Marshal.dump({})
player.characters = Marshal.dump({})

$stderr.puts "Storing user record."
player.store
pid = player.id

$stderr.puts "Looking up user record again (should be cached)."
player2 = PlayerRecord.lookup( pid )

$stderr.puts "Objects are " + (player == player2 ? "" : "not ") + "identical."

$stderr.puts "Stored. Freeing from memory."
player = nil
player2 = nil

$stderr.puts "Released from memory -- garbage-collecting."
GC.start

$stderr.puts "Done. Looking up record #{pid}:"
player = PlayerRecord.lookup( pid )
p player
