#!/usr/bin/ruby -w

require "tableadapter/Mysql"

def IceboxAdapterClass( table )
	TableAdapterClass( "icebox", table, "deveiant", "3l3g4nt", "" )
end

class Song < IceboxAdapterClass( "song" ); end

s = Song.new

songs = Song.lookup( 2, 111, 14, 161, 1024 )

puts Song.columnInfoTable << "\n"

songs.each {|song|
	if song.nil?
		puts "Found nil song"
		next
	end
	puts "Song \##{song.id} #{song.title}: #{song.path} -> (#{song.objectId})"
}


