#!/usr/bin/ruby

# This is a little test to figure out what the best way for the Engine's object
# store to be laid out is.

$LOAD_PATH.unshift ".", "..", "lib", "../lib", "ext", "../ext"

require "utils"
include UtilityFunctions

require 'mues/Object'
require 'mues/ObjectStore'
require 'mues/User'

require 'timeout'
require 'getoptlong'
#require 'profile'

$backend = 'Flatfile'
$memmgr = 'Null'

# Read command-line options
opts = GetoptLong.new
opts.set_options(
	[ '--backend',	'-b',	GetoptLong::REQUIRED_ARGUMENT ],
	[ '--memmgr',	'-m',	GetoptLong::REQUIRED_ARGUMENT ],
	[ '--debug',	'-d',	GetoptLong::NO_ARGUMENT ],
	[ '--help',		'-h',	GetoptLong::NO_ARGUMENT ]
)

opts.each {|opt, val|
	case opt
	when '--backend'
		$backend = val

	when '--memmgr'
		$memmgr = val

	when '--debug'
		$DEBUG = true

	end
}


#####################################################################
###	B E G I N   T E S T S
#####################################################################

header "Testing store/fetch of a user in a #$backend objectstore"

# Create objectstore
header "Creating objectstore"
os = MUES::ObjectStore::create( :name => "testuser",
							    :backend => $backend,
							    :memmgr => $memmgr,
							    :indexes => %w{class username}
							   )
os.debugLevel = 5 if $DEBUG

# Create a new user
header "Creating user"
user = MUES::User::new( :username => 'ged',
					    :realname => 'Ged',
					    :emailAddress => 'ged@FaerieMUD.org',
					    :password => 'furchtbar' )
user.debugLevel = 5 if $DEBUG

userId = user.muesid
message ("-" * 60) + "\nUser => #{user.inspect}\n" + ("-" * 60) + "\n"
							    
# Store the user
header "Storing user"
os.store( user )

# Unset the user variable
header "Freeing user"
user = nil

# Fetch the user by id
header "Fetching user by id"
user = os.retrieve( userId )

writeLine
message "User => #{user.inspect}"
writeLine

# Look up the user using indexes
header "Looking user up by class+name:"
matches = os.lookup( :class => MUES::User, :username => 'ged' )
message ("-" * 60) + "\nMatches => #{matches.inspect}\n" + ("-" * 60) + "\n"

# Unset the user variable again
header "Freeing user"
user = nil

# Try looking the user up repeatedly by id
10.times do |count|
	user = nil
	header "Fetching user by id (iteration #{count})"
	timeout( 3 ) {
		user = os.retrieve( userId )
	}
	message ("-" * 60) + "\nUser => #{user.inspect}\n" + ("-" * 60) + "\n"
	os.store( user )
end

# Close the objectstore
header "Closing objectstore"
os.close

# Drop the objectstore
header "Dropping objectstore"
os.drop



