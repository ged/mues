puts ">>> Adding lib and ext to load path..."
$LOAD_PATH.unshift( "lib", "ext" )
puts "Requiring mues..."

begin
  require "mues"
rescue => e
  $stderr.puts "Ack! MUES library failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end
