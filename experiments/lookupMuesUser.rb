#!/usr/bin/ruby -w

require "mues/Player"
require "tableadapter/Mysql"
require "md5"

$DEBUG = true

def MuesAdapterClass( table )
	TableAdapterClass( "mues", table, "deveiant", "3l3g4nt", "" )
end

class PlayerRecord < MuesAdapterClass( "player" ); end

pid = ARGV.shift || 1

$stderr.puts "Looking up record #{pid}:"
player = PlayerRecord.lookup( pid )
p player
