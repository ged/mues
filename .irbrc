#!/usr/bin/ruby

puts ">>> Adding lib and ext to load path..."
$LOAD_PATH.unshift( "lib", "ext" )

# Try to require the 'mues' library
begin
	puts "Requiring mues..."
	require "mues"

	if $DEBUG
		puts "Turning on logging..."
		outputter = MUES::Logger::Outputter.create( 'color:stderr' )
		MUES::Logger::global.outputters << outputter
		MUES::Logger::global.level = :debug

		MUES::Logger::global.info "Logging enabled."
	end
rescue => e
	$stderr.puts "Ack! MUES library failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end

__END__
Local Variables:
mode: ruby

