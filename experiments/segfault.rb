#!/usr/bin/ruby -w

require "mysql"

begin
	puts "Connecting..."
	h = Mysql.connect( "localhost", "deveiant", "3l3g4nt", "mues" )
	puts "Fetching table info..."
	h.list_fields( "player" ).fetch_fields.each {|f| puts "\t#{f.name}"}
	h.close
rescue StandardError => e
	$stderr.puts "Encountered an error: #{e.message}"
ensure
	puts "In the ensure block..."
end

