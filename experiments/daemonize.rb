#!/usr/bin/ruby -w

def daemonize()

	# First fork
	if Process.fork then Process.exit!(0); end

	# Become session leader
	Process.setsid

	# Second fork
	if Process.fork then Process.exit!(0); end

	# Set CWD to the root dir and set umask
	Dir.chdir( "/" )
	File.umask( 0 )

	# Close all our filehandles and reopen them to /dev/null
	File.open( "/dev/null", File::RDWR ) {|devnull|
		$stdin.close	&& $stdin.reopen( devnull )
		$stdout.close	&& $stdout.reopen( devnull )
		$stderr.close	&& $stderr.reopen( devnull )
	}

	return true
end


daemonize()
$0 = "Daemonized."
sleep 30;
exit 0


