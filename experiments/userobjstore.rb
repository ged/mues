#!/usr/bin/ruby

# This is a little test to figure out what the best way for the Engine's object
# store to be laid out is.

$LOAD_PATH.unshift ".", "..", "lib", "../lib", "ext", "../ext"

require "utils"
include UtilityFunctions

require 'mues'
require 'mues/ObjectStore'
require 'mues/User'

require 'timeout'
#require 'profile'

$backend = 'BerkeleyDB'
$memmgr = 'Null'

header "Testing store/fetch of a user in a #$backend objectstore"

header "Creating objectstore"
os = MUES::ObjectStore::create( :name => "testuser",
							    :backend => $backend,
							    :memmgr => $memmgr,
							    :indexes => %w{class username}
							   )

header "Creating user"
user = MUES::User::new( :username => 'ged',
					    :realname => 'Ged',
					    :emailAddress => 'ged@FaerieMUD.org' )
userId = user.muesid
message ("-" * 60) + "\nUser => #{user.inspect}\n" + ("-" * 60) + "\n"
							    
header "Storing user"
#timeout( 3 ) {
	os.store( user )
#}

header "Freeing user"
user = nil

header "Looking user up by class+name:"
#timeout( 3 ) {
	matches = os.lookup( :class => MUES::User, :username => 'ged' )
	message ("-" * 60) + "\nMatches => #{matches.inspect}\n" + ("-" * 60) + "\n"
#}

header "Freeing user"
user = nil

10.times do |count|
	user = nil
	header "Fetching user by id (iteration #{count})"
	timeout( 3 ) {
		user = os.retrieve( userId )
	}
	message ("-" * 60) + "\nUser => #{user.inspect}\n" + ("-" * 60) + "\n"
	os.store( user )
end

header "Closing objectstore"
#timeout( 3 ) {
	os.close
#}

header "Dropping objectstore"
#timeout( 3 ) {
	os.drop
#}



